import SwiftUI

@main
struct DockfolioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = DockStore.shared

    var body: some Scene {
        Window("Dockfolio", id: "main") {
            EditorWindowView()
                .environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 780, height: 300)
        .commands {
            DockfolioCommands(store: store)
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(store)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.menu)
    }
}
