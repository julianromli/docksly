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
    static func scan() async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) {
            blockingScan()
        }.value
    }

    private static func blockingScan() -> [InstalledApp] {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Applications", isDirectory: true)
        ]

        var seen = Set<String>()
        var results: [InstalledApp] = []

        for root in roots {
            for appURL in appURLs(in: root, extraFolderDepth: 1) {
                let path = appURL.path
                if seen.contains(path) { continue }
                seen.insert(path)
                let info = readInfo(at: appURL)
                results.append(
                    InstalledApp(
                        name: info.name,
                        path: path,
                        bundleIdentifier: info.bundleIdentifier
                    )
                )
            }
        }

        return results.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Top-level `.app` bundles, plus one extra folder level (`Utilities`, `Setapp`).
    private static func appURLs(in directory: URL, extraFolderDepth: Int) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var urls: [URL] = []
        for item in contents {
            if item.pathExtension.lowercased() == "app" {
                urls.append(item)
                continue
            }
            guard extraFolderDepth > 0 else { continue }
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                urls.append(contentsOf: appURLs(in: item, extraFolderDepth: extraFolderDepth - 1))
            }
        }
        return urls
    }

    /// `Bundle(path:)` is too slow and can stall the main thread on large `/Applications` folders.
    private static func readInfo(at appURL: URL) -> (name: String, bundleIdentifier: String?) {
        let fallback = appURL.deletingPathExtension().lastPathComponent
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: plistURL) else {
            return (fallback, nil)
        }
        let bundleIdentifier = info["CFBundleIdentifier"] as? String
        let display = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
        let name = (display?.isEmpty == false) ? display! : fallback
        return (name, bundleIdentifier)
    }
}

