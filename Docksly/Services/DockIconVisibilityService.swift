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
                openSettingsWindow()
            }
        }
    }

    static func apply() {
        NSApp.setActivationPolicy(isVisible ? .regular : .accessory)
    }
}

/// Opens the SwiftUI Settings scene.
/// macOS 14+: `OpenSettingsAction` bound from a live view. Do not send `showSettingsWindow:`.
/// macOS 13: `showPreferencesWindow:`.
func openSettingsWindow() {
    NSApp.activate(ignoringOtherApps: true)
    if #available(macOS 14.0, *) {
        SettingsOpener.open()
    } else {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

/// Menu bar Settings item. `SettingsLink` is required in a menu-style `MenuBarExtra` on macOS 14+.
struct MenuSettingsButton: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",", modifiers: .command)
        } else {
            Button("Settings…") {
                openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
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
        if let action = boxedAction as? OpenSettingsAction {
            action()
        }
        for window in NSApp.windows where isSettingsWindow(window) {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        let id = window.identifier?.rawValue ?? ""
        if id.localizedCaseInsensitiveContains("settings") { return true }
        return window.title.localizedCaseInsensitiveContains("settings")
            || window.title.localizedCaseInsensitiveContains("preferences")
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
