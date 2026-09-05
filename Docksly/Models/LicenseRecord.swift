import Foundation

/// Local license and trial record. The trial start is also stored in Keychain.
struct LicenseRecord: Codable, Equatable {
    var trialStartedAt: Date
    var licenseCode: String
    var isLicensed: Bool
    var lastVerifiedAt: Date?

    init(
        trialStartedAt: Date,
        licenseCode: String = "",
        isLicensed: Bool = false,
        lastVerifiedAt: Date? = nil
    ) {
        self.trialStartedAt = trialStartedAt
        self.licenseCode = licenseCode
        self.isLicensed = isLicensed
        self.lastVerifiedAt = lastVerifiedAt
    }
}

enum LicenseAccessError: LocalizedError {
    case locked

    var errorDescription: String? {
        "Your trial has ended. Enter a license key in Settings to continue."
    }
}

enum LicenseConfig {
    static var apiURL: URL? {
        url(forKey: "DockslyLicenseAPIURL")
    }

    static var checkoutURL: URL? {
        url(forKey: "DockslyCheckoutURL")
    }

    private static func url(forKey key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
