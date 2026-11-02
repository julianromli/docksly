import AppKit
import Foundation

/// Errors from reading or writing the real macOS Dock.
enum DockApplicatorError: LocalizedError, Equatable {
    case preferenceReadFailed
    case preferenceWriteFailed
    case dockRestartFailed(String)
    case cannotResolveApplication(String)

    var errorDescription: String? {
        switch self {
        case .preferenceReadFailed:
            return "Docksly could not read the Dock preference list."
        case .preferenceWriteFailed:
            return "Docksly could not write the Dock preference list."
        case .dockRestartFailed(let detail):
            return "The Dock list was written, but Docksly could not restart Dock. \(detail)"
        case .cannotResolveApplication(let name):
            return "Docksly could not find “\(name)” on this Mac."
        }
    }
}

/// Reads and writes pinned Dock apps and spacers.
///
/// ## Approach
/// There is no public, supported AppKit API that replaces the whole pinned-apps
/// list. macOS stores that list in the `com.apple.dock` preference domain:
///
/// - `persistent-apps` — pinned applications and spacers on the left of the divider
/// - `persistent-others` — folders, stacks, and files on the right
///
/// Finder (left) and Trash (right) are in neither list. This service replaces
/// `persistent-apps` and, from 1.2, `persistent-others` (folders, files, links).
/// It changes Dock size, magnification, position, auto-hide, and recent apps only
/// when a dock turns on its own Dock settings.
///
/// Writes go through `CFPreferencesSetAppValue` + `CFPreferencesAppSynchronize`
/// so `cfprefsd` owns the file. A raw edit of `~/Library/Preferences/com.apple.dock.plist`
/// can be overwritten by the cache. After a successful sync we run `/usr/bin/killall Dock`.
/// Dock relaunches in place. Open apps stay running. You will see a short flicker.
///
/// ## Risks
/// - A malformed tile can make Dock drop that item or, in rare cases, reset the list.
/// - Docksly is **not sandboxed**. The App Sandbox blocks this preference domain
///   and `killall Dock`.
/// - Apple can change the tile dictionary on a future macOS. Test after system updates.
/// - `killall Dock` is the documented community method (dockutil and similar tools).
///   It is not a published AppKit contract.
///
/// Before each apply, the previous `persistent-apps` and `persistent-others`
/// arrays are copied into Application Support so you can restore them by hand.
enum DockApplicator {
    static let dockDomain = "com.apple.dock" as CFString
    static let persistentAppsKey = "persistent-apps" as CFString
    static let persistentOthersKey = "persistent-others" as CFString

    // MARK: - Read

    /// Pinned apps and spacers from the live Dock. Finder and Trash are omitted.
    static func readPinnedItems() throws -> [DockItem] {
        let array = readRawPersistentApps()
        return array.compactMap(parseTile(_:))
    }

    /// Folders, files, and links on the right side of the live Dock.
    static func readOtherItems() -> [DockOtherItem] {
        readRawPersistentOthers().compactMap(parseOtherTile(_:))
    }

    /// Compare key for the whole live Dock. Empty when the Dock cannot be read.
    static func readLiveSignature() throws -> String {
        let apps = try readPinnedItems()
        return DockLayout.signature(apps: apps, others: readOtherItems())
    }

    /// Raw `persistent-apps` tiles, for backup only.
    static func readRawPersistentApps() -> [[String: Any]] {
        readRawArray("persistent-apps")
    }

    /// Raw `persistent-others` tiles, for backup only.
    static func readRawPersistentOthers() -> [[String: Any]] {
        readRawArray("persistent-others")
    }

    /// Reads through `UserDefaults(suiteName:)` after a CFPreferences sync so the
    /// Swift overlay does not have to take an `Unmanaged` retain from
    /// `CFPreferencesCopyAppValue` (the import type changed across Xcode versions).
    private static func readRawArray(_ key: String) -> [[String: Any]] {
        CFPreferencesAppSynchronize(dockDomain)
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        defaults?.synchronize()
        if let array = defaults?.array(forKey: key) as? [[String: Any]] {
            return array
        }
        return []
    }

    /// The Dock settings that a dock can carry, as they are now.
    static func readAppearance() -> DockAppearance {
        CFPreferencesAppSynchronize(dockDomain)
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        let fallback = DockAppearance.systemDefault
        func number(_ key: String) -> Double? {
            (defaults?.object(forKey: key) as? NSNumber)?.doubleValue
        }
        func flag(_ key: String, _ value: Bool) -> Bool {
            (defaults?.object(forKey: key) as? NSNumber)?.boolValue ?? value
        }
        let position = (defaults?.string(forKey: "orientation")).flatMap(DockAppearance.Position.init(rawValue:))
        return DockAppearance(
            isEnabled: true,
            tileSize: number("tilesize") ?? fallback.tileSize,
            magnification: flag("magnification", fallback.magnification),
            largeSize: number("largesize") ?? fallback.largeSize,
            position: position ?? fallback.position,
            autohide: flag("autohide", fallback.autohide),
            showRecents: flag("show-recents", fallback.showRecents)
        ).clamped()
    }

    // MARK: - Write

    /// Replaces pinned apps and spacers, the right side (when `others` is not nil),
    /// and the Dock settings (when `appearance` is on). Then restarts Dock once.
    ///
    /// Does not quit open applications. Apps that are running but not in `items`
    /// can still appear in the Dock until you quit them — that is normal Dock behavior.
    static func apply(
        _ items: [DockItem],
        others: [DockOtherItem]? = nil,
        appearance: DockAppearance? = nil
    ) throws {
        let tiles = items.compactMap { makeTile(from: $0) }
        CFPreferencesSetAppValue(persistentAppsKey, tiles as CFArray, dockDomain)
        if let others {
            let otherTiles = others.compactMap { makeOtherTile(from: $0) }
            CFPreferencesSetAppValue(persistentOthersKey, otherTiles as CFArray, dockDomain)
        }
        if let appearance, appearance.isEnabled {
            for (key, value) in appearanceValues(appearance) {
                CFPreferencesSetAppValue(key as CFString, value, dockDomain)
            }
        }
        guard CFPreferencesAppSynchronize(dockDomain) else {
            throw DockApplicatorError.preferenceWriteFailed
        }
        try restartDock()
    }

    /// The `com.apple.dock` keys and values for a set of Dock settings.
    static func appearanceValues(_ appearance: DockAppearance) -> [(String, CFPropertyList)] {
        let value = appearance.clamped()
        return [
            ("tilesize", NSNumber(value: value.tileSize)),
            ("magnification", NSNumber(value: value.magnification)),
            ("largesize", NSNumber(value: value.largeSize)),
            ("orientation", value.position.rawValue as NSString),
            ("autohide", NSNumber(value: value.autohide)),
            ("show-recents", NSNumber(value: value.showRecents)),
        ]
    }

    static func writePersistentApps(_ tiles: [[String: Any]]) throws {
        CFPreferencesSetAppValue(persistentAppsKey, tiles as CFArray, dockDomain)
        guard CFPreferencesAppSynchronize(dockDomain) else {
            throw DockApplicatorError.preferenceWriteFailed
        }
    }

    // MARK: - Path helpers

    static func resolveApplicationPath(bundleIdentifier: String?, fallbackPath: String?) -> String? {
        if let bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url.path
        }
        if let fallbackPath, FileManager.default.fileExists(atPath: fallbackPath) {
            return fallbackPath
        }
        return fallbackPath
    }

    static func bundleIdentifier(at path: String) -> String? {
        Bundle(path: path)?.bundleIdentifier
    }

    static func displayName(at path: String) -> String {
        FileManager.default.displayName(atPath: path)
            .replacingOccurrences(of: ".app", with: "")
    }

    // MARK: - Tile encode / decode

    /// Right-side tile in the same form that `dockutil` writes.
    static func makeOtherTile(from item: DockOtherItem) -> [String: Any]? {
        let guid = Int.random(in: 1 ... Int.max)
        switch item.kind {
        case .folder, .file:
            guard let path = item.path, !path.isEmpty else { return nil }
            let isFolder = item.kind == .folder
            let fileURL = URL(fileURLWithPath: path, isDirectory: isFolder)
            var tileData: [String: Any] = [
                "file-data": [
                    "_CFURLString": fileURL.absoluteString,
                    "_CFURLStringType": 15
                ] as [String: Any],
                "file-label": item.title,
                "file-type": isFolder ? 2 : 41
            ]
            if isFolder {
                tileData["directory"] = 1
                tileData["displayas"] = (item.display ?? .folder).rawValue
                tileData["arrangement"] = (item.sort ?? .dateModified).rawValue
                tileData["showas"] = (item.view ?? .automatic).rawValue
            }
            return [
                "GUID": guid,
                "tile-type": isFolder ? "directory-tile" : "file-tile",
                "tile-data": tileData
            ]
        case .link:
            guard let url = item.url, !url.isEmpty else { return nil }
            return [
                "GUID": guid,
                "tile-type": "url-tile",
                "tile-data": [
                    "label": item.title,
                    "url": [
                        "_CFURLString": url,
                        "_CFURLStringType": 15
                    ] as [String: Any]
                ] as [String: Any]
            ]
        }
    }

    /// Reads a right-side tile. Returns nil for tile types that Docksly does not know.
    static func parseOtherTile(_ dict: [String: Any]) -> DockOtherItem? {
        let tileType = (dict["tile-type"] as? String) ?? ""
        guard let tileData = dict["tile-data"] as? [String: Any] else { return nil }
        switch tileType {
        case "url-tile":
            let urlData = tileData["url"] as? [String: Any]
            guard let url = urlData?["_CFURLString"] as? String, !url.isEmpty else { return nil }
            return .link(url: url, label: tileData["label"] as? String)
        case "directory-tile", "file-tile":
            let fileData = tileData["file-data"] as? [String: Any]
            let urlType = fileData?["_CFURLStringType"] as? Int ?? 0
            guard let path = normalizePath(fileData?["_CFURLString"] as? String, type: urlType) else {
                return nil
            }
            let label = tileData["file-label"] as? String
            let fileType = tileData["file-type"] as? Int
            let isFolder = tileType == "directory-tile" || fileType == 2 || fileType == 3
            if isFolder {
                return .folder(
                    path: path,
                    label: label,
                    display: (tileData["displayas"] as? Int).flatMap(DockOtherItem.FolderDisplay.init(rawValue:)) ?? .folder,
                    sort: (tileData["arrangement"] as? Int).flatMap(DockOtherItem.FolderSort.init(rawValue:)) ?? .dateModified,
                    view: (tileData["showas"] as? Int).flatMap(DockOtherItem.FolderView.init(rawValue:)) ?? .automatic
                )
            }
            return .file(path: path, label: label)
        default:
            return nil
        }
    }

    private static func makeTile(from item: DockItem) -> [String: Any]? {
        switch item.kind {
        case .spacer:
            return [
                "GUID": Int.random(in: 1 ... Int.max),
                "tile-type": "spacer-tile",
                "tile-data": [String: Any]()
            ]
        case .application:
            let path = resolveApplicationPath(
                bundleIdentifier: item.bundleIdentifier,
                fallbackPath: item.bookmarkPath
            ) ?? item.bookmarkPath
            guard let path, !path.isEmpty else { return nil }
            let fileURL = URL(fileURLWithPath: path, isDirectory: true)
            var tileData: [String: Any] = [
                "file-data": [
                    "_CFURLString": fileURL.absoluteString,
                    "_CFURLStringType": 15
                ] as [String: Any],
                "file-type": 41
            ]
            if let name = item.displayName, !name.isEmpty {
                tileData["file-label"] = name
            }
            if let bundleIdentifier = item.bundleIdentifier, !bundleIdentifier.isEmpty {
                tileData["bundle-identifier"] = bundleIdentifier
            }
            return [
                "GUID": Int.random(in: 1 ... Int.max),
                "tile-type": "file-tile",
                "tile-data": tileData
            ]
        }
    }

    private static func parseTile(_ dict: [String: Any]) -> DockItem? {
        let tileType = (dict["tile-type"] as? String) ?? ""
        if tileType == "spacer-tile"
            || tileType == "small-spacer-tile"
            || tileType == "flex-spacer-tile" {
            return .spacer()
        }

        // Skip directory / URL tiles that belong on the right side if they leak in.
        if tileType == "directory-tile" || tileType == "url-tile" {
            return nil
        }

        guard let tileData = dict["tile-data"] as? [String: Any] else { return nil }
        let fileData = tileData["file-data"] as? [String: Any]
        let urlString = fileData?["_CFURLString"] as? String
        let urlType = fileData?["_CFURLStringType"] as? Int ?? 0
        let path = normalizePath(urlString, type: urlType)

        let bundleID = (tileData["bundle-identifier"] as? String)
            ?? path.flatMap { bundleIdentifier(at: $0) }
        let label = (tileData["file-label"] as? String)
            ?? path.map { displayName(at: $0) }

        guard bundleID != nil || path != nil else { return nil }

        return .application(
            bundleIdentifier: bundleID,
            path: path,
            displayName: label
        )
    }

    /// `_CFURLStringType` 0 is a POSIX path. Type 15 is a `file://` URL.
    private static func normalizePath(_ value: String?, type: Int) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if type == 15 || value.hasPrefix("file:") {
            if let url = URL(string: value) {
                return url.path
            }
            if let url = URL(string: value.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? value) {
                return url.path
            }
        }
        return value
    }

    // MARK: - Dock restart

    /// Restarts the Dock process. Open apps stay running. A short flicker is expected.
    static func restartDock() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw DockApplicatorError.dockRestartFailed(error.localizedDescription)
        }

        // 0 = signaled; 1 = no matching process. Both are acceptable.
        if process.terminationStatus != 0 && process.terminationStatus != 1 {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw DockApplicatorError.dockRestartFailed(
                message.isEmpty
                    ? "killall exited with status \(process.terminationStatus)."
                    : message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}
