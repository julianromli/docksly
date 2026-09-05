import AppKit

/// Keeps the process alive when the editor window closes so the menu extra stays.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
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
