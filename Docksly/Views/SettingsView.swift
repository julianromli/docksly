import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var license: LicenseStore
    @State private var launchAtLogin = LaunchAtLoginService.isEnabled
    @State private var status = LaunchAtLoginService.statusDescription
    @State private var showInDock = DockIconVisibilityService.isVisible
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text(license.statusText)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                LicenseActivationForm()
            } header: {
                Text("License")
            } footer: {
                Text("The trial starts the first time you open Docksly. After 24 hours, enter a license key from Mayar.")
            }

            Section {
                Toggle("Open Docksly at login", isOn: launchBinding)
                    .help("Uses the macOS login-item service. Put the app in Applications for a reliable result.")
                Toggle("Show Docksly in Dock", isOn: showInDockBinding)
                    .help("When off, Docksly stays in the menu bar only. There is no Dock icon for the running app.")
                if !showInDock {
                    Text("When off, Docksly stays in the menu bar only. Close the window at any time. The app stays running. Use Manage Docks… or Settings… in the menu bar to open it again. A Docksly tile in a dock layout is separate from this toggle.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if SMAppService.mainApp.status == .requiresApproval {
                    Button("Open Login Items…") {
                        openLoginItems()
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("Docksly stores docks on this Mac. License checks use the Mayar service.")
            }

            Section("Data") {
                HStack {
                    Text("Library")
                    Spacer()
                    Button("Show in Finder") { reveal(libraryURL) }
                        .help(libraryURL.path)
                }
                HStack {
                    Text("Backups")
                    Spacer()
                    Button("Show in Finder") { reveal(backupsURL) }
                        .help(backupsURL.path)
                }
            }

            #if DEBUG
            Section {
                Button("Simulate trial ended") {
                    license.simulateTrialEnded()
                }
                Button("Restore local license") {
                    license.restoreLocalLicense()
                }
                .disabled(license.record.licenseCode.isEmpty)
            } header: {
                Text("Developer")
            } footer: {
                Text("Local only. These buttons do not call Mayar and do not use an activation slot.")
            }
            #endif
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 640)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            refresh()
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try LaunchAtLoginService.setEnabled(newValue)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
                refresh()
            }
        )
    }

    private var showInDockBinding: Binding<Bool> {
        Binding(
            get: { showInDock },
            set: { newValue in
                DockIconVisibilityService.setVisible(newValue)
                showInDock = DockIconVisibilityService.isVisible
            }
        )
    }

    private func refresh() {
        launchAtLogin = LaunchAtLoginService.isEnabled
        status = LaunchAtLoginService.statusDescription
        showInDock = DockIconVisibilityService.isVisible
    }

    private func openLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            _ = NSWorkspace.shared.open(fallback)
        }
    }

    private var libraryURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("Docksly/library.json")
    }

    private var backupsURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("Docksly/backups", isDirectory: true)
    }

    private func reveal(_ url: URL) {
        let folder = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
