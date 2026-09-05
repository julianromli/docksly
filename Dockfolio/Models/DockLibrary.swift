import Foundation

/// On-disk document for every saved dock plus which one was last applied.
struct DockLibrary: Codable, Equatable {
    var profiles: [DockProfile]
    /// Profile last written to the real macOS Dock.
    var activeProfileID: UUID?
    /// Signature of items at the last successful apply. Used to detect drift.
    var lastAppliedSignature: String?

    init(
        profiles: [DockProfile] = [],
        activeProfileID: UUID? = nil,
        lastAppliedSignature: String? = nil
    ) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.lastAppliedSignature = lastAppliedSignature
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
    }
}
