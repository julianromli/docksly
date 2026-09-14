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
        var didFront = false
        for window in NSApp.windows where isSettingsWindow(window) {
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            didFront = true
        }
        if didFront { return }
        for window in NSApp.windows where isUserWindow(window) && window.identifier?.rawValue != "main" {
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

/// Opens the SwiftUI Settings scene.
/// macOS 14+: `OpenSettingsAction` bound from a live view. Do not send `showSettingsWindow:`.
/// macOS 13: `showPreferencesWindow:`.
func openSettingsWindow() {
    AppWindowPresentation.activate()
    if #available(macOS 14.0, *) {
        SettingsOpener.open()
    } else {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
    DispatchQueue.main.async {
        AppWindowPresentation.activate()
        AppWindowPresentation.orderFrontSettings()
    }
}

/// Menu bar Settings item. `SettingsLink` is required in a menu-style `MenuBarExtra` on macOS 14+.
struct MenuSettingsButton: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            MenuSettingsLink()
        } else {
            Button("Settings…") {
                openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

@available(macOS 14.0, *)
private struct MenuSettingsLink: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        SettingsLink {
            Text("Settings…")
        }
        .simultaneousGesture(TapGesture().onEnded {
            present()
        })
        .keyboardShortcut(",", modifiers: .command)
        .onAppear {
            SettingsOpener.bind(openSettings)
        }
    }

    private func present() {
        AppWindowPresentation.activate()
        openSettings()
        DispatchQueue.main.async {
            AppWindowPresentation.activate()
            AppWindowPresentation.orderFrontSettings()
        }
    }
}

enum SettingsOpener {
    private static var boxedAction: Any?

    @available(macOS 14.0, *)
    static func bind(_ action: OpenSettingsAction) {
        boxedAction = action
    }

    @available(macOS 14.0, *)
    static func open() {
        AppWindowPresentation.activate()
        if let action = boxedAction as? OpenSettingsAction {
            action()
        }
        AppWindowPresentation.orderFrontSettings()
    }
}

struct SettingsOpenerBinder: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.modifier(SettingsOpenerBinder14())
        } else {
            content
        }
    }
}

@available(macOS 14.0, *)
private struct SettingsOpenerBinder14: ViewModifier {
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content.onAppear {
            SettingsOpener.bind(openSettings)
        }
    }
}

extension View {
    func bindsSettingsOpener() -> some View {
        modifier(SettingsOpenerBinder())
    }
}
