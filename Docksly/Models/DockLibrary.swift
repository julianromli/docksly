import Foundation

/// On-disk document for every saved dock plus which one was last applied.
struct DockLibrary: Codable, Equatable {
    /// Version of this file format. Files from 1.0.x have no value and read as 1.
    static let currentSchemaVersion = 3

    var schemaVersion: Int
    var profiles: [DockProfile]
    /// Profile last written to the real macOS Dock.
    var activeProfileID: UUID?
    /// Signature of items at the last successful apply. Used to detect drift.
    var lastAppliedSignature: String?
    /// Dock that was active before a Focus filter switched docks. Restored when the Focus turns off.
    var focusRestoreProfileID: UUID?

    init(
        profiles: [DockProfile] = [],
        activeProfileID: UUID? = nil,
        lastAppliedSignature: String? = nil,
        focusRestoreProfileID: UUID? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.lastAppliedSignature = lastAppliedSignature
        self.focusRestoreProfileID = focusRestoreProfileID
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case profiles
        case activeProfileID
        case lastAppliedSignature
        case focusRestoreProfileID
    }

    /// New fields are optional, so files from older versions still open.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        profiles = try container.decode([DockProfile].self, forKey: .profiles)
        activeProfileID = try container.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        lastAppliedSignature = try container.decodeIfPresent(String.self, forKey: .lastAppliedSignature)
        focusRestoreProfileID = try container.decodeIfPresent(UUID.self, forKey: .focusRestoreProfileID)
    }

    /// Brings an older file up to `currentSchemaVersion`.
    /// `currentOthers` reads the right side of the live Dock. It runs only when a dock needs it.
    mutating func migrate(currentOthers: () -> [DockOtherItem]) {
        if schemaVersion < 2 {
            // 1.1 adds only optional fields. Nothing to convert.
            schemaVersion = 2
        }
        if schemaVersion < 3 {
            // 1.2: each dock owns the right side. Copy the live right side into
            // every dock, so nothing on screen changes after the update.
            fillMissingOthers(with: currentOthers)
            schemaVersion = 3
        }
    }

    /// Gives every dock with no right-side data a copy of `currentOthers`.
    mutating func fillMissingOthers(with currentOthers: () -> [DockOtherItem]) {
        guard profiles.contains(where: { $0.otherItems == nil }) else { return }
        let others = currentOthers()
        for index in profiles.indices where profiles[index].otherItems == nil {
            profiles[index].otherItems = others.map { item in
                var copy = item
                copy.id = UUID()
                return copy
            }
        }
    }

    func profile(id: UUID) -> DockProfile? {
        profiles.first { $0.id == id }
    }

    mutating func upsert(_ profile: DockProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }

    mutating func remove(id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileID == id {
            activeProfileID = nil
            lastAppliedSignature = nil
        }
        if focusRestoreProfileID == id {
            focusRestoreProfileID = nil
        }
    }

    /// The dock after `id` in list order, wrapping at the end.
    func profile(after id: UUID?) -> DockProfile? {
        guard !profiles.isEmpty else { return nil }
        guard let id, let index = profiles.firstIndex(where: { $0.id == id }) else {
            return profiles.first
        }
        return profiles[(index + 1) % profiles.count]
    }
}
