import SwiftUI

@main
struct DockslyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = DockStore.shared
    @ObservedObject private var license = LicenseStore.shared
    @ObservedObject private var cleanUp = CleanUpController.shared

    var body: some Scene {
        Window("Docksly", id: "main") {
            EditorWindowView()
                .environmentObject(store)
                .environmentObject(license)
                .environmentObject(cleanUp)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 780, height: DockslyStyle.windowIdealHeight)
        .commands {
            DockslyCommands(store: store, license: license)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(license)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(store)
                .environmentObject(license)
                .environmentObject(cleanUp)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}
