import AppKit
import SwiftUI

/// Controls whether Docksly shows its icon in the macOS Dock.
/// When `isVisible` is true, the icon shows only while a Docksly window is open
/// (minimized counts). When false, Docksly stays in the menu bar only.
/// Missing key means true.
enum DockIconVisibilityService {
    private static let key = "showInDock"
    private static let closeHintKey = "didShowCloseHint"

    static var isVisible: Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Set at quit so closing windows during termination does not show the hint.
    static var isTerminating = false

    /// Set while Docksly closes the editor itself (launch at login).
    static var suppressCloseHint = false

    private static var observers: [NSObjectProtocol] = []

    static func setVisible(_ visible: Bool) {
        UserDefaults.standard.set(visible, forKey: key)
        apply()
        if visible {
            AppWindowPresentation.activate()
        } else {
            // Menu-bar-only: do not reopen Settings. Leave a clean accessory state.
            AppWindowPresentation.hideUserWindows()
            DispatchQueue.main.async {
                AppWindowPresentation.hideUserWindows()
            }
        }
    }

    /// Sets the activation policy from the toggle and the open windows.
    /// `closing` is a window that is about to close and must not count.
    static func apply(excluding closing: NSWindow? = nil) {
        let showIcon = isVisible && hasOpenUserWindow(excluding: closing)
        let policy: NSApplication.ActivationPolicy = showIcon ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if policy == .regular {
            // A change from accessory to regular does not show the menu bar until activation.
            AppWindowPresentation.activate()
        }
    }

    /// Watches window open, close, and minimize events to update the Dock icon.
    static func startObservingWindows() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let refreshNames: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
        ]
        for name in refreshNames {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let window = note.object as? NSWindow, countsForDock(window) else { return }
                apply()
            })
        }
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow, countsForDock(window) else { return }
            apply(excluding: window)
            if !hasOpenUserWindow(excluding: window) {
                // Wait until the window is gone before the hint shows.
                DispatchQueue.main.async { showCloseHintIfNeeded() }
            }
        })
    }

    static func hasOpenUserWindow(excluding closing: NSWindow? = nil) -> Bool {
        NSApp.windows.contains { window in
            window !== closing
                && countsForDock(window)
                && (window.isVisible || window.isMiniaturized)
        }
    }

    /// Editor and Settings count. Menu bar chrome and panels (alerts, open panels) do not.
    private static func countsForDock(_ window: NSWindow) -> Bool {
        !(window is NSPanel) && AppWindowPresentation.isUserWindow(window)
    }

    /// One-time notice the first time the last window closes while the Dock icon is on.
    private static func showCloseHintIfNeeded() {
        guard isVisible, !isTerminating, !suppressCloseHint,
              !UserDefaults.standard.bool(forKey: closeHintKey),
              !hasOpenUserWindow() else { return }
        UserDefaults.standard.set(true, forKey: closeHintKey)
        AppWindowPresentation.activate()
        let alert = NSAlert()
        alert.messageText = "Docksly is still running"
        alert.informativeText = "Open it again from the Docksly icon in the menu bar. To quit, choose Quit Docksly from that menu."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

/// Detects a launch by macOS at login, so Docksly can start in the menu bar only.
enum LoginLaunchDetector {
    /// Reads the launch Apple event. Call it in `applicationWillFinishLaunching`
    /// or `applicationDidFinishLaunching`, while that event is current.
    /// Best effort: if macOS does not mark the event, this returns false.
    static func launchedAtLogin() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication,
              let property = event.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return property.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

enum AppWindowPresentation {
    static func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hide the editor and Settings. Keep menu-bar chrome.
    static func hideUserWindows() {
        for window in NSApp.windows where isUserWindow(window) {
            window.orderOut(nil)
        }
    }

    static func presentEditor(using openWindow: OpenWindowAction) {
        activate()
        openWindow(id: "main")
        DispatchQueue.main.async {
            activate()
            orderFrontEditor()
            let visible = NSApp.windows.contains {
                $0.identifier?.rawValue == "main" && $0.isVisible
            }
            if !visible {
                openWindow(id: "main")
                DispatchQueue.main.async {
                    activate()
                    orderFrontEditor()
                }
            }
        }
    }

    static func orderFrontEditor() {
        for window in NSApp.windows where window.identifier?.rawValue == "main" {
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
        }
    }

    static func orderFrontSettings() {
        for window in NSApp.windows where isSettingsWindow(window) {
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
        }
    }

    static func isUserWindow(_ window: NSWindow) -> Bool {
        if isMenuBarChrome(window) { return false }
        return window.canBecomeKey || window.canBecomeMain
    }

    static func isMenuBarChrome(_ window: NSWindow) -> Bool {
        let name = window.className
        if name.contains("StatusBar") || name.contains("NSStatus") || name.contains("MenuBarExtra") {
            return true
        }
        return window.level == .statusBar
    }

    static func isSettingsWindow(_ window: NSWindow) -> Bool {
        if isMenuBarChrome(window) { return false }
        if window.identifier?.rawValue == "main" { return false }
        let id = window.identifier?.rawValue ?? ""
        if id.localizedCaseInsensitiveContains("settings") { return true }
        return window.title.localizedCaseInsensitiveContains("settings")
            || window.title.localizedCaseInsensitiveContains("preferences")
    }
}

/// Menu bar Settings item. `SettingsLink` opens Settings on macOS 14+.
/// Do not send `showSettingsWindow:`.
struct MenuSettingsButton: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            MenuSettingsLink()
        } else {
            Button("Settings…") {
                AppWindowPresentation.activate()
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                DispatchQueue.main.async {
                    AppWindowPresentation.activate()
                    AppWindowPresentation.orderFrontSettings()
                }
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

@available(macOS 14.0, *)
private struct MenuSettingsLink: View {
    var body: some View {
        SettingsLink {
            Text("Settings…")
        }
        .simultaneousGesture(TapGesture().onEnded {
            AppWindowPresentation.activate()
            DispatchQueue.main.async {
                AppWindowPresentation.activate()
                AppWindowPresentation.orderFrontSettings()
            }
        })
        .keyboardShortcut(",", modifiers: .command)
    }
}
