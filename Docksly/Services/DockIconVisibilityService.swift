import AppKit

/// Controls whether Docksly shows its icon in the macOS Dock.
/// Missing key means true, so existing installs keep current behavior.
enum DockIconVisibilityService {
    private static let key = "showInDock"

    static var isVisible: Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func setVisible(_ visible: Bool) {
        UserDefaults.standard.set(visible, forKey: key)
        if visible {
            apply()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Switching to accessory hides the Settings window. Bring it back.
            NSApp.setActivationPolicy(.accessory)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
                showSettings()
            }
        }
    }

    static func apply() {
        NSApp.setActivationPolicy(isVisible ? .regular : .accessory)
    }

    private static func showSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
