import Foundation

/// One tile in a saved Dock layout: a pinned application or a spacer.
struct DockItem: Identifiable, Codable, Equatable, Hashable {
    enum Kind: String, Codable, Hashable {
        case application
        case spacer
    }

    var id: UUID
    var kind: Kind
    /// Bundle ID when known. Preferred over path when we resolve the app later.
    var bundleIdentifier: String?
    /// Last known filesystem path of the `.app` bundle.
    var bookmarkPath: String?
    var displayName: String?

    static func application(
        id: UUID = UUID(),
        bundleIdentifier: String?,
        path: String?,
        displayName: String?
    ) -> DockItem {
        DockItem(
            id: id,
            kind: .application,
            bundleIdentifier: bundleIdentifier,
            bookmarkPath: path,
            displayName: displayName
        )
    }

    static func spacer(id: UUID = UUID()) -> DockItem {
        DockItem(
            id: id,
            kind: .spacer,
            bundleIdentifier: nil,
            bookmarkPath: nil,
            displayName: nil
        )
    }

    var title: String {
        switch kind {
        case .spacer:
            return "Spacer"
        case .application:
            if let displayName, !displayName.isEmpty { return displayName }
            if let bookmarkPath {
                return URL(fileURLWithPath: bookmarkPath)
                    .deletingPathExtension()
                    .lastPathComponent
            }
            return bundleIdentifier ?? "Application"
        }
    }

    /// Stable compare key for the live Dock vs a saved profile.
    var layoutSignature: String {
        switch kind {
        case .spacer:
            return "spacer"
        case .application:
            let identity = bundleIdentifier?.lowercased()
                ?? bookmarkPath?.lowercased()
                ?? id.uuidString
            return "app:\(identity)"
        }
    }
}

extension Array where Element == DockItem {
    var layoutSignature: String {
        map(\.layoutSignature).joined(separator: "|")
    }
}
