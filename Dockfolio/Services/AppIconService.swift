import AppKit
import Foundation

/// Loads `.app` icons through `NSWorkspace` and keeps a small memory cache.
final class AppIconService {
    static let shared = AppIconService()

    private let cache = NSCache<NSString, NSImage>()
    private let missing = NSImage(systemSymbolName: "questionmark.app", accessibilityDescription: "Missing application")

    private init() {
        cache.countLimit = 256
    }

    func icon(for item: DockItem) -> NSImage {
        switch item.kind {
        case .spacer:
            return NSImage(systemSymbolName: "space", accessibilityDescription: "Spacer")
                ?? NSImage()
        case .application:
            let key = (item.bundleIdentifier ?? item.bookmarkPath ?? item.id.uuidString) as NSString
            if let cached = cache.object(forKey: key) {
                return cached
            }
            if let image = loadApplicationIcon(item) {
                cache.setObject(image, forKey: key)
                return image
            }
            return missing ?? NSImage()
        }
    }

    func icon(forAppAt path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 128, height: 128)
        cache.setObject(image, forKey: key)
        return image
    }

    var isMissingSymbol: NSImage {
        missing ?? NSImage()
    }

    func isResolvable(_ item: DockItem) -> Bool {
        guard item.kind == .application else { return true }
        return DockApplicator.resolveApplicationPath(
            bundleIdentifier: item.bundleIdentifier,
            fallbackPath: item.bookmarkPath
        ).map { FileManager.default.fileExists(atPath: $0) } ?? false
    }

    private func loadApplicationIcon(_ item: DockItem) -> NSImage? {
        guard let path = DockApplicator.resolveApplicationPath(
            bundleIdentifier: item.bundleIdentifier,
            fallbackPath: item.bookmarkPath
        ), FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 128, height: 128)
        return image
    }
}

/// Installed applications we can offer in the Add Application sheet.
struct InstalledApp: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var bundleIdentifier: String?
}

enum InstalledAppScanner {
    static func scan() -> [InstalledApp] {
        let directories = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]
        var seen = Set<String>()
        var results: [InstalledApp] = []

        for directory in directories {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in contents where item.pathExtension == "app" {
                let path = item.path
                if seen.contains(path) { continue }
                seen.insert(path)
                let name = FileManager.default.displayName(atPath: path)
                    .replacingOccurrences(of: ".app", with: "")
                results.append(
                    InstalledApp(
                        name: name,
                        path: path,
                        bundleIdentifier: Bundle(path: path)?.bundleIdentifier
                    )
                )
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
