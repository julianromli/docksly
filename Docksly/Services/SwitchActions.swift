import AppKit
import Foundation

/// What a dock does besides its Dock layout: quit other apps, open its apps.
@MainActor
enum SwitchActions {
    private static let confirmedKey = "confirmedQuitOthers"

    /// Runs after a dock is written to the Dock. Quits first, then opens.
    static func run(items: [DockItem], quitOthers: Bool, keepOpen: [KeepOpenApp]) {
        if quitOthers {
            quitApps(notIn: items, keepOpen: Set(keepOpen.map(\.bundleIdentifier)))
        }
        openApps(items)
    }

    /// Asks apps to quit normally. Docksly never forces an app to close. An app can refuse,
    /// or ask the user to save first.
    private static func quitApps(notIn items: [DockItem], keepOpen: Set<String>) {
        let running = NSWorkspace.shared.runningApplications.map {
            QuitPlan.RunningApp(
                bundleIdentifier: $0.bundleIdentifier,
                isRegularApp: $0.activationPolicy == .regular
            )
        }
        let dockApps = Set(items.compactMap(\.bundleIdentifier))
        let ids = QuitPlan.bundleIdentifiersToQuit(
            running: running,
            dockApps: dockApps,
            keepOpen: keepOpen,
            ownBundleIdentifier: Bundle.main.bundleIdentifier ?? "app.docksly.Docksly"
        )
        for id in ids {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) {
                app.terminate()
            }
        }
    }

    /// Opens each app that has "open when this dock is used". A running app comes to the front.
    /// An app with an open target opens that target with the app.
    private static func openApps(_ items: [DockItem]) {
        for item in items where item.kind == .application && item.opensWhenUsed == true {
            guard let path = DockApplicator.resolveApplicationPath(
                bundleIdentifier: item.bundleIdentifier,
                fallbackPath: item.bookmarkPath
            ) else { continue }
            let appURL = URL(fileURLWithPath: path)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true

            if let target = item.openTarget.flatMap(OpenTarget.url(from:)) {
                NSWorkspace.shared.open([target], withApplicationAt: appURL, configuration: config) { _, _ in }
                continue
            }
            let running = item.bundleIdentifier.map { NSRunningApplication.runningApplications(withBundleIdentifier: $0) } ?? []
            if let app = running.first {
                app.activate(options: [.activateAllWindows])
            } else {
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in }
            }
        }
    }

    /// The first time the user turns on "Quit Apps Not in This Dock", explain what it does.
    /// Returns false when the user cancels.
    static func confirmQuitOthers() -> Bool {
        if UserDefaults.standard.bool(forKey: confirmedKey) { return true }
        AppWindowPresentation.activate()
        let alert = NSAlert()
        alert.messageText = "Quit apps that are not in this dock?"
        alert.informativeText = "When you use this dock, Docksly asks the other apps to quit. Apps can ask you to save first, and Docksly never forces them to close. Finder and Docksly are never quit. Apps in Always Keep Open are kept."
        alert.addButton(withTitle: "Turn On")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        UserDefaults.standard.set(true, forKey: confirmedKey)
        return true
    }

    /// Picks a file, folder, or web address to open with an app. Returns nil when cancelled.
    static func chooseOpenTarget() -> String? {
        AppWindowPresentation.activate()
        let alert = NSAlert()
        alert.messageText = "Open a web address with this app?"
        alert.informativeText = "Type a web address, or choose a file or folder instead."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://example.com"
        alert.accessoryView = field
        alert.addButton(withTitle: "Use Address")
        alert.addButton(withTitle: "Choose File or Folder…")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return OpenTarget.webAddress(field.stringValue)
        case .alertSecondButtonReturn:
            let panel = NSOpenPanel()
            panel.title = "Choose what this app opens"
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { return nil }
            return url.path
        default:
            return nil
        }
    }
}
