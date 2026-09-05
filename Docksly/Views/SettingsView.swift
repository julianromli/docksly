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
                Toggle("Open Docksly at login", isOn: launchBinding)
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
                Text("Docksly stores docks in your Application Support folder. There is no account and no network sync.")
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
