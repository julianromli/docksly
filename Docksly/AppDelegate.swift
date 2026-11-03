import AppKit

/// Keeps the process alive when the editor window closes so the menu extra stays.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var launchedAtLogin = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        DockIconVisibilityService.isTerminating = true
        return .terminateNow
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchedAtLogin = LoginLaunchDetector.launchedAtLogin()
        // Apply hidden policy early to avoid a brief Dock icon flash.
        if launchedAtLogin || !DockIconVisibilityService.isVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconVisibilityService.startObservingWindows()
        HotkeyService.start()
        DisplayWatcher.start()
        if launchedAtLogin {
            DisplayWatcher.applyForCurrentDisplays()
        }
        if launchedAtLogin {
            // Start in the menu bar only. SwiftUI opens the editor at launch, so close it.
            DockIconVisibilityService.suppressCloseHint = true
            closeEditorWindows()
            DispatchQueue.main.async {
                self.closeEditorWindows()
                DockIconVisibilityService.apply()
                // The hint check from each close runs on the next pass. Clear the flag after it.
                DispatchQueue.main.async {
                    DockIconVisibilityService.suppressCloseHint = false
                }
            }
        } else {
            DispatchQueue.main.async {
                DockIconVisibilityService.apply()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.activate(ignoringOtherApps: true)
        // With no Dock icon, a reopen comes from Finder or Spotlight. Menu bar chrome
        // windows always exist, so check for an open editor or Settings window instead.
        if !flag || !DockIconVisibilityService.hasOpenUserWindow() {
            NotificationCenter.default.post(name: .dockslyOpenEditor, object: nil)
        }
        return true
    }

    private func closeEditorWindows() {
        for window in NSApp.windows where window.identifier?.rawValue == "main" {
            window.close()
        }
    }
}

extension Notification.Name {
    static let dockslyOpenEditor = Notification.Name("docksly.openEditor")
}
