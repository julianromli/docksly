import AppKit
import Foundation
import Security
import SwiftUI

/// Trial clock plus the local licensed flag after a successful Mayar verify.
@MainActor
final class LicenseStore: ObservableObject {
    static let shared = LicenseStore()
    static let trialDuration: TimeInterval = 24 * 60 * 60
    static let lockedMessage = "Your trial has ended. Enter a license key in Settings to continue."

    @Published private(set) var record: LicenseRecord
    @Published var isActivating = false
    @Published var lastError: String?

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var expiryTimer: Timer?

    var isLicensed: Bool {
        record.isLicensed
    }

    var trialEndsAt: Date {
        record.trialStartedAt.addingTimeInterval(Self.trialDuration)
    }

    var isTrialActive: Bool {
        !isLicensed && Date() < trialEndsAt
    }

    var hasAccess: Bool {
        isLicensed || isTrialActive
    }

    var statusText: String {
        if isLicensed {
            return "Licensed"
        }
        return trialRemainingText()
    }

    init(fileManager: FileManager = .default) {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = support.appendingPathComponent("Docksly", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("license.json")

        let fileRecord = Self.loadRecord(from: fileURL, decoder: decoder)
        let trialStart = Self.resolveTrialStart(fileRecord: fileRecord)
        record = LicenseRecord(
            trialStartedAt: trialStart,
            licenseCode: fileRecord?.licenseCode ?? "",
            isLicensed: fileRecord?.isLicensed ?? false,
            lastVerifiedAt: fileRecord?.lastVerifiedAt
        )
        persist()
        scheduleExpiryTick()
    }

    func trialRemainingText(now: Date = Date()) -> String {
        let remaining = trialEndsAt.timeIntervalSince(now)
        if remaining <= 0 {
            return "Trial ended"
        }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours >= 1 {
            return hours == 1 ? "Trial · 1 hour left" : "Trial · \(hours) hours left"
        }
        if minutes >= 1 {
            return minutes == 1 ? "Trial · 1 minute left" : "Trial · \(minutes) minutes left"
        }
        return "Trial · less than 1 minute left"
    }

    func activate(code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Enter a license key."
            return
        }
        isActivating = true
        lastError = nil
        do {
            let result = try await LicenseClient.verify(licenseCode: trimmed)
            if result.active {
                record.licenseCode = trimmed
                record.isLicensed = true
                record.lastVerifiedAt = Date()
                persist()
                lastError = nil
                stopExpiryTimer()
                objectWillChange.send()
            } else {
                lastError = result.userMessage
            }
        } catch {
            lastError = "Docksly could not reach the license service."
        }
        isActivating = false
    }

    func openCheckout() {
        guard let url = LicenseConfig.checkoutURL else {
            lastError = "The purchase page is not configured."
            return
        }
        NSWorkspace.shared.open(url)
    }

    func clearError() {
        lastError = nil
    }

    #if DEBUG
    /// Local only. Does not call Mayar. Does not use an activation slot.
    func simulateTrialEnded() {
        record.isLicensed = false
        record.trialStartedAt = Date().addingTimeInterval(-(Self.trialDuration + 60))
        lastError = nil
        persist()
        scheduleExpiryTick()
        objectWillChange.send()
    }

    /// Local only. Puts the saved key back as licensed. Does not call Mayar.
    func restoreLocalLicense() {
        guard !record.licenseCode.isEmpty else {
            lastError = "This Mac has no saved license key."
            return
        }
        record.isLicensed = true
        lastError = nil
        persist()
        stopExpiryTimer()
        objectWillChange.send()
    }
    #endif

    private func persist() {
        do {
            let data = try encoder.encode(record)
            try data.write(to: fileURL, options: .atomic)
            TrialKeychain.write(record.trialStartedAt)
        } catch {
            lastError = "Docksly could not save the license record."
        }
    }

    private func scheduleExpiryTick() {
        stopExpiryTimer()
        guard !isLicensed else { return }
        let remaining = trialEndsAt.timeIntervalSinceNow
        let interval = remaining <= 0 ? 1 : min(max(remaining, 1), 30)
        expiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleExpiryTick()
            }
        }
        if let expiryTimer {
            RunLoop.main.add(expiryTimer, forMode: .common)
        }
    }

    private func handleExpiryTick() {
        objectWillChange.send()
        if isLicensed || !isTrialActive {
            stopExpiryTimer()
        }
    }

    private func stopExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    private static func loadRecord(from url: URL, decoder: JSONDecoder) -> LicenseRecord? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(LicenseRecord.self, from: data)
    }

    private static func resolveTrialStart(fileRecord: LicenseRecord?) -> Date {
        if let keyed = TrialKeychain.read() {
            return keyed
        }
        if let fromFile = fileRecord?.trialStartedAt {
            TrialKeychain.write(fromFile)
            return fromFile
        }
        let now = Date()
        TrialKeychain.write(now)
        return now
    }
}

private enum TrialKeychain {
    static let service = "app.docksly.Docksly"
    static let account = "trialStartedAt"

    static func read() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        return parseDate(raw)
    }

    static func write(_ date: Date) {
        let data = isoFormatter.string(from: date).data(using: .utf8) ?? Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess {
            return
        }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func parseDate(_ raw: String) -> Date? {
        if let date = isoFormatter.date(from: raw) {
            return date
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
