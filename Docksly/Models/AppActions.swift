import Foundation

/// An app that Docksly never quits when it switches docks, chosen in Settings.
struct KeepOpenApp: Codable, Equatable, Identifiable, Hashable {
    var bundleIdentifier: String
    var name: String

    var id: String { bundleIdentifier }
}

/// Turns a stored open target into a URL. A target is a file or folder path, or a web address.
enum OpenTarget {
    static func url(from target: String) -> URL? {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }
        guard trimmed.contains("://"), let url = URL(string: trimmed), url.scheme != nil else { return nil }
        return url
    }

    /// Accepts a web address and adds nothing else. Returns nil for text that is not a web address.
    static func webAddress(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = DockOtherItem.normalizedLinkURL(trimmed) else { return nil }
        return url
    }
}

/// Decides which running apps a dock switch quits. Pure, so it can be tested.
enum QuitPlan {
    /// Apps that Docksly never quits, whatever the user chooses.
    static let alwaysProtected: Set<String> = ["com.apple.finder"]

    struct RunningApp: Equatable {
        var bundleIdentifier: String?
        var isRegularApp: Bool
    }

    /// Bundle IDs to ask to quit: regular apps that are not in the new dock, not kept open, and not protected.
    static func bundleIdentifiersToQuit(
        running: [RunningApp],
        dockApps: Set<String>,
        keepOpen: Set<String>,
        ownBundleIdentifier: String
    ) -> [String] {
        let keep = dockApps
            .union(keepOpen)
            .union(alwaysProtected)
            .union([ownBundleIdentifier])
        return running.compactMap { app -> String? in
            guard app.isRegularApp, let id = app.bundleIdentifier, !keep.contains(id) else { return nil }
            return id
        }
    }
}
