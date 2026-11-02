import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var license: LicenseStore
    @State private var launchAtLogin = LaunchAtLoginService.isEnabled
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var showInDock = DockIconVisibilityService.isVisible
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("General") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Open Docksly at login", isOn: launchBinding)
                        .help("Uses the macOS login-item service. Put the app in Applications for a reliable result.")
                    if let loginWarning {
                        Label(loginWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if loginStatus == .requiresApproval {
                        Button("Open Login Items…") {
                            openLoginItems()
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show Docksly in Dock", isOn: showInDockBinding)
                    Text(showInDock
                        ? "Shows while a Docksly window is open. Docksly stays in the menu bar after you close it."
                        : "Docksly stays in the menu bar only.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                if license.isLicensed {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Licensed")
                                .font(.body.weight(.medium))
                            Text("Lifetime license on this Mac")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(license.statusText)
                        .font(.body.weight(.medium))
                        .monospacedDigit()
                    LicenseActivationForm()
                }
            } header: {
                Text("License")
            } footer: {
                if !license.isLicensed {
                    Text("The trial starts the first time you open Docksly. After 24 hours, enter a license key from Mayar. License checks use the Mayar service.")
                }
            }

            Section {
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
            } header: {
                Text("Data")
            } footer: {
                Text("Docksly keeps your docks on this Mac.")
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

            Section {
            } footer: {
                Text(versionText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            refresh()
        }
    }

    /// Shown only when the login item has a problem.
    private var loginWarning: String? {
        switch loginStatus {
        case .notFound, .requiresApproval:
            return LaunchAtLoginService.statusDescription
        default:
            return nil
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Docksly \(version) (\(build))"
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
        loginStatus = SMAppService.mainApp.status
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
