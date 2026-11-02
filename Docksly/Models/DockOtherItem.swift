import Foundation

/// One tile on the right side of the Dock (`persistent-others`): a folder, a file, or a web link.
struct DockOtherItem: Identifiable, Codable, Equatable, Hashable {
    enum Kind: String, Codable, Hashable {
        case folder
        case file
        case link
    }

    /// Dock "Display as". Raw values match the Dock's `displayas` key.
    enum FolderDisplay: Int, Codable, CaseIterable, Hashable {
        case stack = 0
        case folder = 1

        var title: String {
            switch self {
            case .stack: return "Stack"
            case .folder: return "Folder"
            }
        }
    }

    /// Dock "Sort by". Raw values match the Dock's `arrangement` key.
    enum FolderSort: Int, Codable, CaseIterable, Hashable {
        case name = 1
        case dateAdded = 2
        case dateModified = 3
        case dateCreated = 4
        case kind = 5

        var title: String {
            switch self {
            case .name: return "Name"
            case .dateAdded: return "Date Added"
            case .dateModified: return "Date Modified"
            case .dateCreated: return "Date Created"
            case .kind: return "Kind"
            }
        }
    }

    /// Dock "View content as". Raw values match the Dock's `showas` key.
    enum FolderView: Int, Codable, CaseIterable, Hashable {
        case automatic = 0
        case fan = 1
        case grid = 2
        case list = 3

        var title: String {
            switch self {
            case .automatic: return "Automatic"
            case .fan: return "Fan"
            case .grid: return "Grid"
            case .list: return "List"
            }
        }
    }

    var id: UUID
    var kind: Kind
    /// File-system path for a folder or a file.
    var path: String?
    /// Full URL for a link, for example `https://example.com`.
    var url: String?
    var label: String?
    var display: FolderDisplay?
    var sort: FolderSort?
    var view: FolderView?

    static func folder(
        id: UUID = UUID(),
        path: String,
        label: String? = nil,
        display: FolderDisplay = .folder,
        sort: FolderSort = .dateModified,
        view: FolderView = .automatic
    ) -> DockOtherItem {
        DockOtherItem(
            id: id,
            kind: .folder,
            path: path,
            url: nil,
            label: label,
            display: display,
            sort: sort,
            view: view
        )
    }

    static func file(id: UUID = UUID(), path: String, label: String? = nil) -> DockOtherItem {
        DockOtherItem(id: id, kind: .file, path: path, url: nil, label: label, display: nil, sort: nil, view: nil)
    }

    static func link(id: UUID = UUID(), url: String, label: String? = nil) -> DockOtherItem {
        DockOtherItem(id: id, kind: .link, path: nil, url: url, label: label, display: nil, sort: nil, view: nil)
    }

    var title: String {
        if let label, !label.isEmpty { return label }
        switch kind {
        case .folder, .file:
            guard let path else { return kind == .folder ? "Folder" : "File" }
            return FileManager.default.displayName(atPath: path)
        case .link:
            guard let url, let host = URL(string: url)?.host else { return url ?? "Link" }
            return host
        }
    }

    /// Stable compare key for the live Dock vs a saved dock.
    var layoutSignature: String {
        switch kind {
        case .folder:
            let options = "\(display?.rawValue ?? 1),\(sort?.rawValue ?? 3),\(view?.rawValue ?? 0)"
            return "folder:\(Self.normalized(path)):\(options)"
        case .file:
            return "file:\(Self.normalized(path))"
        case .link:
            return "link:\(url?.lowercased() ?? "")"
        }
    }

    /// Ignores a trailing slash and letter case, so `/a/b/` and `/A/b` match.
    private static func normalized(_ path: String?) -> String {
        guard var path, !path.isEmpty else { return "" }
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path.lowercased()
    }

    /// Adds `https://` when the user types a bare host such as `example.com`.
    /// Returns nil when the text is not a usable URL.
    static func normalizedLinkURL(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), let scheme = url.scheme, !scheme.isEmpty else { return nil }
        if scheme == "http" || scheme == "https" {
            guard let host = url.host, host.contains(".") || host == "localhost" else { return nil }
        }
        return candidate
    }
}

extension Array where Element == DockOtherItem {
    var layoutSignature: String {
        map(\.layoutSignature).joined(separator: "|")
    }
}

/// Dock settings that a dock can carry. Docksly writes them only when `isEnabled` is true.
struct DockAppearance: Codable, Equatable, Hashable {
    enum Position: String, Codable, CaseIterable, Hashable {
        case left
        case bottom
        case right

        var title: String {
            switch self {
            case .left: return "Left"
            case .bottom: return "Bottom"
            case .right: return "Right"
            }
        }
    }

    /// Dock icon sizes range from 16 to 128 points.
    static let sizeRange: ClosedRange<Double> = 16 ... 128

    var isEnabled: Bool
    var tileSize: Double
    var magnification: Bool
    var largeSize: Double
    var position: Position
    var autohide: Bool
    var showRecents: Bool

    /// macOS defaults for a new user account.
    static let systemDefault = DockAppearance(
        isEnabled: false,
        tileSize: 48,
        magnification: false,
        largeSize: 64,
        position: .bottom,
        autohide: false,
        showRecents: true
    )

    /// Keeps sizes inside the range the Dock accepts.
    func clamped() -> DockAppearance {
        var copy = self
        copy.tileSize = min(max(tileSize, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        copy.largeSize = min(max(largeSize, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        return copy
    }
}

/// Compare key for a whole Dock: apps on the left, then the right side.
enum DockLayout {
    static func signature(apps: [DockItem], others: [DockOtherItem]) -> String {
        "\(apps.layoutSignature)#\(others.layoutSignature)"
    }
}
