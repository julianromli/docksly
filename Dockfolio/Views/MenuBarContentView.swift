import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.library.profiles) { profile in
            Button {
                if profile.id == store.selectedProfileID {
                    store.applySelected(saveFirst: true)
                } else {
                    store.apply(profileID: profile.id)
                }
            } label: {
                HStack {
                    if store.library.activeProfileID == profile.id {
                        Image(systemName: "checkmark")
                    }
                    Text(profile.name)
                }
            }
            .disabled(store.isApplying)
        }

        Divider()

        Button("Manage Docks…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettingsWindow()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Dockfolio") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .accessibilityLabel("Dockfolio")
            .onReceive(NotificationCenter.default.publisher(for: .dockfolioOpenEditor)) { _ in
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
    }
}

func openSettingsWindow() {
    if #available(macOS 14.0, *) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
