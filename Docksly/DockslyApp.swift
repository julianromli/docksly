import SwiftUI

@main
struct DockslyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = DockStore.shared

    var body: some Scene {
        Window("Docksly", id: "main") {
            EditorWindowView()
                .environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 780, height: DockslyStyle.windowIdealHeight)
        .commands {
            DockslyCommands(store: store)
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
