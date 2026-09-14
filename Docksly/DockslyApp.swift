import SwiftUI

@main
struct DockslyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = DockStore.shared
    @ObservedObject private var license = LicenseStore.shared

    var body: some Scene {
        Window("Docksly", id: "main") {
            EditorWindowView()
                .environmentObject(store)
                .environmentObject(license)
                .bindsSettingsOpener()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 780, height: DockslyStyle.windowIdealHeight)
        .commands {
            DockslyCommands(store: store, license: license)
        }

        Settings {
            SettingsView()
                .environmentObject(license)
        }

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(store)
                .environmentObject(license)
                .bindsSettingsOpener()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.menu)
    }
}
