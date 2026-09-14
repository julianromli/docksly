import AppKit

/// Keeps the process alive when the editor window closes so the menu extra stays.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Apply hidden policy early to avoid a brief Dock icon flash.
        if !DockIconVisibilityService.isVisible {
            DockIconVisibilityService.apply()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconVisibilityService.apply()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.activate(ignoringOtherApps: true)
        if !flag {
            if sender.windows.isEmpty {
                NotificationCenter.default.post(name: .dockslyOpenEditor, object: nil)
            } else {
                sender.windows.forEach { $0.makeKeyAndOrderFront(nil) }
            }
        }
        return true
    }
}

extension Notification.Name {
    static let dockslyOpenEditor = Notification.Name("docksly.openEditor")
}
