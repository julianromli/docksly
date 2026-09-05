import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = LaunchAtLoginService.isEnabled
    @State private var status = LaunchAtLoginService.statusDescription
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open Dockfolio at login", isOn: launchBinding)
                    .help("Uses the macOS login-item service. Put the app in Applications for a reliable result.")
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
                Text("Dockfolio stores docks in your Application Support folder. There is no account and no network sync.")
            }

            Section("Data") {
                LabeledContent("Library") {
                    Text(libraryPath)
                        .font(.caption)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Backups") {
                    Text(backupsPath)
                        .font(.caption)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
        .onAppear {
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

    private func refresh() {
        launchAtLogin = LaunchAtLoginService.isEnabled
        status = LaunchAtLoginService.statusDescription
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

    private var libraryPath: String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return support?
            .appendingPathComponent("Dockfolio/library.json")
            .path
            ?? "~/Library/Application Support/Dockfolio/library.json"
    }

    private var backupsPath: String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return support?
            .appendingPathComponent("Dockfolio/backups")
            .path
            ?? "~/Library/Application Support/Dockfolio/backups"
    }
}
