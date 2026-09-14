import AppKit
import SwiftUI

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

    static func apply() {
        NSApp.setActivationPolicy(isVisible ? .regular : .accessory)
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
