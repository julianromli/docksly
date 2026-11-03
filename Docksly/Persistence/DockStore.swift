import AppKit
import Foundation
import SwiftUI

/// Local JSON store plus the in-memory editor draft.
@MainActor
final class DockStore: ObservableObject {
    static let shared = DockStore()

    @Published private(set) var library: DockLibrary
    @Published var selectedProfileID: UUID
    @Published var draftName: String
    @Published var draftColor: ProfileColor
    @Published var draftItems: [DockItem]
    @Published var draftOthers: [DockOtherItem]
    @Published var draftAppearance: DockAppearance?
    @Published var draftQuitOthers = false
    @Published var lastError: String?
    @Published var isApplying = false
    @Published var liveSignature: String = ""
    @Published var wantsNewDockName = false
    @Published var wantsAddApp = false
    @Published var wantsAddLink = false
    @Published var wantsAppearance = false

    private let fileURL: URL
    private let backupsDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var selectedProfile: DockProfile {
        library.profile(id: selectedProfileID)
            ?? library.profiles.first
            ?? DockProfile(name: "Main")
    }

    var isDirty: Bool {
        let saved = selectedProfile
        return saved.items != draftItems
            || (saved.otherItems ?? []) != draftOthers
            || saved.appearance != draftAppearance
            || (saved.quitOthersOnSwitch ?? false) != draftQuitOthers
            || saved.name != draftName
            || saved.color != draftColor
    }

    var isSelectedActive: Bool {
        library.activeProfileID == selectedProfileID
    }

    /// True when this profile is the last applied layout and the live Dock still matches.
    var isSelectedCurrent: Bool {
        isSelectedActive
            && !isDirty
            && !liveSignature.isEmpty
            && liveSignature == draftSignature
    }

    var draftSignature: String {
        DockLayout.signature(apps: draftItems, others: draftOthers)
    }

    var statusText: String {
        let count = draftItems.count + draftOthers.count
        let noun = count == 1 ? "item" : "items"
        if isApplying {
            return "Applying… · \(count) \(noun)"
        }
        if isDirty {
            return "Unsaved · \(count) \(noun)"
        }
        if isSelectedCurrent {
            return "On Dock · \(count) \(noun)"
        }
        return "Not on Dock · \(count) \(noun)"
    }

    init(fileManager: FileManager = .default) {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = DockStore.resolveSupportFolder(in: support, fileManager: fileManager)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("library.json")
        backupsDirectory = folder.appendingPathComponent("backups", isDirectory: true)
        try? fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)

        let loadedLibrary: DockLibrary
        if let data = try? Data(contentsOf: fileURL),
           var loaded = try? decoder.decode(DockLibrary.self, from: data),
           !loaded.profiles.isEmpty {
            loaded.migrate(currentOthers: DockApplicator.readOtherItems)
            // An older Docksly can save this file and drop the right side. Fill it
            // again on every load, so an apply never clears the right side by mistake.
            loaded.fillMissingOthers(with: DockApplicator.readOtherItems)
            loadedLibrary = loaded
        } else {
            loadedLibrary = DockStore.makeFirstLaunchLibrary()
        }

        let initialID = loadedLibrary.activeProfileID ?? loadedLibrary.profiles[0].id
        let profile = loadedLibrary.profile(id: initialID) ?? loadedLibrary.profiles[0]
        library = loadedLibrary
        selectedProfileID = initialID
        draftName = profile.name
        draftColor = profile.color
        draftItems = profile.items
        draftOthers = profile.otherItems ?? []
        draftAppearance = profile.appearance
        draftQuitOthers = profile.quitOthersOnSwitch ?? false
        persist()
        refreshLiveSignature()
    }

    // MARK: - Selection

    func select(profileID: UUID) {
        guard library.profile(id: profileID) != nil else { return }
        if isDirty, LicenseStore.shared.hasAccess {
            // Keep unsaved work on the current profile before we leave it.
            saveDraft(applyIfActive: false)
        }
        selectedProfileID = profileID
        loadDraft(from: profileID)
        lastError = nil
    }

    func loadDraft(from profileID: UUID) {
        guard let profile = library.profile(id: profileID) else { return }
        draftName = profile.name
        draftColor = profile.color
        draftItems = profile.items
        draftOthers = profile.otherItems ?? []
        draftAppearance = profile.appearance
        draftQuitOthers = profile.quitOthersOnSwitch ?? false
    }

    // MARK: - Mutations

    func renameDraft(_ name: String) {
        guard !rejectIfLocked() else { return }
        draftName = name
    }

    func commitDraftName() {
        guard !rejectIfLocked() else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        draftName = trimmed.isEmpty ? "Untitled Dock" : trimmed
    }

    func setDraftColor(_ color: ProfileColor) {
        guard !rejectIfLocked() else { return }
        draftColor = color
    }

    func replaceDraftItems(_ items: [DockItem]) {
        guard !rejectIfLocked() else { return }
        guard items != draftItems else { return }
        draftItems = items
    }

    func moveItem(id: UUID, toIndex dest: Int) {
        guard !rejectIfLocked() else { return }
        guard let from = draftItems.firstIndex(where: { $0.id == id }) else { return }
        let clamped = min(max(dest, 0), draftItems.count - 1)
        guard from != clamped else { return }
        var items = draftItems
        let item = items.remove(at: from)
        items.insert(item, at: clamped)
        draftItems = items
    }

    func removeItem(id: UUID) {
        guard !rejectIfLocked() else { return }
        draftItems.removeAll { $0.id == id }
    }

    func addSpacer() {
        guard !rejectIfLocked() else { return }
        draftItems.append(.spacer())
    }

    @discardableResult
    func addApplication(path: String) -> Bool {
        if rejectIfLocked() { return false }
        let bundleID = DockApplicator.bundleIdentifier(at: path)
        let name = DockApplicator.displayName(at: path)
        if draftItems.contains(where: { item in
            item.kind == .application
                && (
                    (bundleID != nil && item.bundleIdentifier == bundleID)
                        || item.bookmarkPath == path
                )
        }) {
            lastError = "“\(name)” is already in this dock."
            return false
        }
        draftItems.append(
            .application(bundleIdentifier: bundleID, path: path, displayName: name)
        )
        lastError = nil
        return true
    }

    // MARK: - Right side (folders, files, links)

    func addFolder(path: String) {
        addOther(.folder(path: path))
    }

    func addFile(path: String) {
        addOther(.file(path: path))
    }

    /// Returns false when the text is not a usable URL.
    @discardableResult
    func addLink(_ text: String, label: String?) -> Bool {
        guard let url = DockOtherItem.normalizedLinkURL(text) else {
            lastError = "Enter a full web address, for example https://example.com."
            return false
        }
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        addOther(.link(url: url, label: (trimmed?.isEmpty ?? true) ? nil : trimmed))
        return true
    }

    private func addOther(_ item: DockOtherItem) {
        guard !rejectIfLocked() else { return }
        let key = (item.path ?? item.url)?.lowercased()
        if draftOthers.contains(where: { $0.kind == item.kind && ($0.path ?? $0.url)?.lowercased() == key }) {
            lastError = "“\(item.title)” is already in this dock."
            return
        }
        draftOthers.append(item)
        lastError = nil
    }

    func removeOther(id: UUID) {
        guard !rejectIfLocked() else { return }
        draftOthers.removeAll { $0.id == id }
    }

    func moveOther(id: UUID, toIndex dest: Int) {
        guard !rejectIfLocked() else { return }
        guard let from = draftOthers.firstIndex(where: { $0.id == id }) else { return }
        let clamped = min(max(dest, 0), draftOthers.count - 1)
        guard from != clamped else { return }
        let item = draftOthers.remove(at: from)
        draftOthers.insert(item, at: clamped)
    }

    func updateOther(id: UUID, _ change: (inout DockOtherItem) -> Void) {
        guard !rejectIfLocked() else { return }
        guard let index = draftOthers.firstIndex(where: { $0.id == id }) else { return }
        change(&draftOthers[index])
    }

    /// Turning this on is confirmed by the caller first. See `SwitchActions.confirmQuitOthers`.
    func setDraftQuitOthers(_ on: Bool) {
        guard !rejectIfLocked() else { return }
        draftQuitOthers = on
    }

    func updateItem(id: UUID, _ change: (inout DockItem) -> Void) {
        guard !rejectIfLocked() else { return }
        guard let index = draftItems.firstIndex(where: { $0.id == id }) else { return }
        change(&draftItems[index])
    }

    // MARK: - Display rules and keep-open apps (1.3)

    func upsertDisplayRule(_ rule: DisplayRule) {
        guard !rejectIfLocked() else { return }
        library.displayRules = DisplayRuleResolver.upsert(rule, into: library.displayRules ?? [])
        persist()
    }

    func removeDisplayRule(id: UUID) {
        guard !rejectIfLocked() else { return }
        library.displayRules?.removeAll { $0.id == id }
        persist()
    }

    func setAlwaysKeepOpen(_ apps: [KeepOpenApp]) {
        guard !rejectIfLocked() else { return }
        library.alwaysKeepOpen = apps
        persist()
    }

    func setDraftAppearance(_ appearance: DockAppearance?) {
        guard !rejectIfLocked() else { return }
        draftAppearance = appearance?.clamped()
    }

    func captureLiveDockIntoDraft() {
        guard !rejectIfLocked() else { return }
        do {
            draftItems = try DockApplicator.readPinnedItems()
            draftOthers = DockApplicator.readOtherItems()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Profiles

    /// Creates a dock from what the real Dock shows now, then selects it.
    @discardableResult
    func createDockFromLiveDock(named name: String) -> DockProfile? {
        if rejectIfLocked() { return nil }
        do {
            let items = try DockApplicator.readPinnedItems()
            let others = DockApplicator.readOtherItems()
            let profile = createDock(named: name, items: items, others: others)
            let signature = DockLayout.signature(apps: items, others: others)
            library.activeProfileID = profile.id
            library.lastAppliedSignature = signature
            liveSignature = signature
            persist()
            lastError = nil
            return profile
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func createDock(
        named name: String? = nil,
        items: [DockItem]? = nil,
        others: [DockOtherItem]? = nil
    ) -> DockProfile {
        if rejectIfLocked() {
            return selectedProfile
        }
        if isDirty {
            saveDraft(applyIfActive: false)
        }
        let used = Set(library.profiles.map(\.name))
        let color = ProfileColor.palette.first { candidate in
            !library.profiles.contains { $0.color == candidate }
        } ?? ProfileColor.palette[library.profiles.count % ProfileColor.palette.count]

        var label = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if label.isEmpty {
            label = uniqueName(from: "New Dock", used: used)
        }
        let profile = DockProfile(
            name: label,
            color: color,
            items: items ?? draftItems,
            otherItems: others ?? draftOthers,
            appearance: items == nil ? draftAppearance : nil
        )
        library.upsert(profile)
        selectedProfileID = profile.id
        loadDraft(from: profile.id)
        persist()
        return profile
    }

    func deleteSelectedDock() {
        guard !rejectIfLocked() else { return }
        guard library.profiles.count > 1 else {
            lastError = "Keep at least one dock."
            return
        }
        let removedID = selectedProfileID
        library.remove(id: removedID)
        if let next = library.profiles.first {
            selectedProfileID = next.id
            loadDraft(from: next.id)
        }
        persist()
    }

    // MARK: - Save / apply

    func saveDraft(applyIfActive: Bool) {
        guard !rejectIfLocked() else { return }
        commitDraftName()
        var profile = selectedProfile
        profile.name = draftName.isEmpty ? "Untitled Dock" : draftName
        profile.color = draftColor
        profile.items = draftItems
        profile.otherItems = draftOthers
        profile.appearance = draftAppearance
        profile.quitOthersOnSwitch = draftQuitOthers
        profile.updatedAt = Date()
        library.upsert(profile)
        persist()
        lastError = nil
        if applyIfActive, isSelectedActive {
            applySelected(saveFirst: false)
        }
    }

    func applySelected(saveFirst: Bool) {
        guard !rejectIfLocked() else { return }
        if saveFirst {
            saveDraft(applyIfActive: false)
        }
        apply(profileID: selectedProfileID, useDraft: true)
    }

    func clearError() {
        lastError = nil
    }

    /// True when `profileID` is the last applied dock and the real Dock still matches it.
    func isProfileOnDock(_ profileID: UUID) -> Bool {
        guard library.activeProfileID == profileID,
              let profile = library.profile(id: profileID) else { return false }
        refreshLiveSignature()
        return !liveSignature.isEmpty && liveSignature == profile.layoutSignature
    }

    /// Saves unsaved edits in the editor so a switch from outside the editor does not drop them.
    func saveDraftIfDirty() {
        guard isDirty, LicenseStore.shared.hasAccess else { return }
        saveDraft(applyIfActive: false)
    }

    func setFocusRestoreProfileID(_ id: UUID?) {
        guard library.focusRestoreProfileID != id else { return }
        library.focusRestoreProfileID = id
        persist()
    }

    /// Writes a dock to the real Dock. With `useDraft`, the editor's unsaved
    /// layout is written instead of the saved one.
    func apply(profileID: UUID, useDraft: Bool = false) {
        guard !rejectIfLocked() else { return }
        guard let profile = library.profile(id: profileID) else { return }
        let draft = useDraft && profileID == selectedProfileID
        let items = draft ? draftItems : profile.items
        // Nil means "no right-side data": leave the right side of the Dock as it is.
        let others: [DockOtherItem]? = draft ? draftOthers : profile.otherItems
        let appearance = draft ? draftAppearance : profile.appearance
        let quitOthers = draft ? draftQuitOthers : (profile.quitOthersOnSwitch ?? false)
        let signature = DockLayout.signature(
            apps: items,
            others: others ?? DockApplicator.readOtherItems()
        )
        isApplying = true
        lastError = nil
        do {
            writeDockBackup()
            try DockApplicator.apply(items, others: others, appearance: appearance)
            SwitchActions.run(items: items, quitOthers: quitOthers, keepOpen: library.alwaysKeepOpen ?? [])
            library.activeProfileID = profileID
            library.lastAppliedSignature = signature
            liveSignature = signature
            persist()
            if selectedProfileID != profileID {
                selectedProfileID = profileID
                loadDraft(from: profileID)
            }
        } catch {
            lastError = error.localizedDescription
            presentApplyFailure(error.localizedDescription)
        }
        isApplying = false
    }

    func refreshLiveSignature() {
        do {
            liveSignature = try DockApplicator.readLiveSignature()
        } catch {
            liveSignature = ""
        }
    }

    // MARK: - Export / import

    func exportLibrary(to url: URL) throws {
        try requireAccess()
        let data = try encoder.encode(library)
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    func exportSelectedDock(to url: URL) throws {
        try requireAccess()
        commitDraftName()
        var snapshot = selectedProfile
        snapshot.name = draftName
        snapshot.color = draftColor
        snapshot.items = draftItems
        snapshot.otherItems = draftOthers
        snapshot.appearance = draftAppearance
        snapshot.quitOthersOnSwitch = draftQuitOthers
        snapshot.updatedAt = Date()
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    func `import`(from url: URL) throws {
        try requireAccess()
        let data = try Data(contentsOf: url)
        if var incoming = try? decoder.decode(DockLibrary.self, from: data), !incoming.profiles.isEmpty {
            // Exports from before 1.2 have no right side. Use the live right side for them.
            incoming.fillMissingOthers(with: DockApplicator.readOtherItems)
            var lastImportedID: UUID?
            for var profile in incoming.profiles {
                if library.profile(id: profile.id) != nil {
                    profile.id = UUID()
                }
                profile.name = uniqueName(from: profile.name, used: Set(library.profiles.map(\.name)))
                library.upsert(profile)
                lastImportedID = profile.id
            }
            if let lastImportedID {
                selectedProfileID = lastImportedID
                loadDraft(from: lastImportedID)
            }
            persist()
            return
        }
        var profile = try decoder.decode(DockProfile.self, from: data)
        if profile.otherItems == nil {
            profile.otherItems = DockApplicator.readOtherItems()
        }
        if library.profile(id: profile.id) != nil {
            profile.id = UUID()
        }
        profile.name = uniqueName(from: profile.name, used: Set(library.profiles.map(\.name)))
        library.upsert(profile)
        selectedProfileID = profile.id
        loadDraft(from: profile.id)
        persist()
    }

    // MARK: - Persistence

    @discardableResult
    private func rejectIfLocked() -> Bool {
        guard !LicenseStore.shared.hasAccess else { return false }
        lastError = LicenseStore.lockedMessage
        return true
    }

    private func requireAccess() throws {
        if rejectIfLocked() {
            throw LicenseAccessError.locked
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(library)
            try data.write(to: fileURL, options: Data.WritingOptions.atomic)
        } catch {
            lastError = "Docksly could not save your docks. \(error.localizedDescription)"
        }
    }

    private func writeDockBackup() {
        let tiles: [String: Any] = [
            "persistent-apps": DockApplicator.readRawPersistentApps(),
            "persistent-others": DockApplicator.readRawPersistentOthers()
        ]
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        // Dock tiles include bookmark NSData and sometimes CFURL values.
        // JSONSerialization raises NSInvalidArgumentException for those.
        // Prefer XML plist; fall back to a JSON snapshot of parsed items.
        if PropertyListSerialization.propertyList(tiles, isValidFor: .xml) {
            let url = backupsDirectory.appendingPathComponent("dock-\(stamp).plist")
            do {
                let data = try PropertyListSerialization.data(
                    fromPropertyList: tiles,
                    format: .xml,
                    options: 0
                )
                try data.write(to: url, options: Data.WritingOptions.atomic)
                pruneBackups(keeping: 10)
                return
            } catch {
                // Fall through to JSON so apply still leaves a file.
            }
        }
        let url = backupsDirectory.appendingPathComponent("dock-\(stamp).json")
        let snapshot: [DockItem] = (try? DockApplicator.readPinnedItems()) ?? []
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url, options: Data.WritingOptions.atomic)
        }
        pruneBackups(keeping: 10)
    }

    private func pruneBackups(keeping limit: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let sorted = files.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l > r
        }
        for stale in sorted.dropFirst(limit) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    private func uniqueName(from base: String, used: Set<String>) -> String {
        if !used.contains(base) { return base }
        var index = 2
        while used.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func presentApplyFailure(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Docksly could not apply this dock"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Uses `Docksly/`. Moves a leftover `Dockfolio/` folder once if the new library is missing.
    private static func resolveSupportFolder(in support: URL, fileManager: FileManager) -> URL {
        let folder = support.appendingPathComponent("Docksly", isDirectory: true)
        let library = folder.appendingPathComponent("library.json")
        let legacy = support.appendingPathComponent("Dockfolio", isDirectory: true)
        let legacyLibrary = legacy.appendingPathComponent("library.json")
        if !fileManager.fileExists(atPath: library.path),
           fileManager.fileExists(atPath: legacyLibrary.path) {
            if !fileManager.fileExists(atPath: folder.path) {
                try? fileManager.moveItem(at: legacy, to: folder)
            } else {
                try? fileManager.copyItem(at: legacyLibrary, to: library)
                let legacyBackups = legacy.appendingPathComponent("backups", isDirectory: true)
                let backups = folder.appendingPathComponent("backups", isDirectory: true)
                if fileManager.fileExists(atPath: legacyBackups.path),
                   !fileManager.fileExists(atPath: backups.path) {
                    try? fileManager.copyItem(at: legacyBackups, to: backups)
                }
            }
        }
        return folder
    }

    private static func makeFirstLaunchLibrary() -> DockLibrary {
        let items = (try? DockApplicator.readPinnedItems()) ?? []
        let others = DockApplicator.readOtherItems()
        let main = DockProfile(
            name: "Main",
            color: ProfileColor.palette[0],
            items: items,
            otherItems: others
        )
        return DockLibrary(
            profiles: [main],
            activeProfileID: main.id,
            lastAppliedSignature: DockLayout.signature(apps: items, others: others)
        )
    }
}
