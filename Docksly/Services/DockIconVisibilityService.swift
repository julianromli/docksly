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
        apply()
    }

    static func apply() {
        NSApp.setActivationPolicy(isVisible ? .regular : .accessory)
    }
}
