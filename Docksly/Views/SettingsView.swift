import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

/// The panes in the Settings sidebar, in display order.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case displays
    case keepOpen
    case license
    case data
    #if DEBUG
    case developer
    #endif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .displays: return "Displays"
        case .keepOpen: return "Keep Open"
        case .license: return "License"
        case .data: return "Data"
        #if DEBUG
        case .developer: return "Developer"
        #endif
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard.fill"
        case .displays: return "display.2"
        case .keepOpen: return "pin.fill"
        case .license: return "checkmark.seal.fill"
        case .data: return "externaldrive.fill"
        #if DEBUG
        case .developer: return "hammer.fill"
        #endif
        }
    }

    var tint: Color {
        switch self {
        case .general: return .gray
        case .shortcuts: return .indigo
        case .displays: return .blue
        case .keepOpen: return .orange
        case .license: return .green
        case .data: return .teal
        #if DEBUG
        case .developer: return .pink
        #endif
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: DockStore
    @EnvironmentObject private var license: LicenseStore
    @AppStorage("settingsPane") private var storedPane = SettingsPane.general.rawValue
    @State private var showSwitchHUD = SwitchHUD.isEnabled
    @State private var ruleDockID: UUID?
    @State private var launchAtLogin = LaunchAtLoginService.isEnabled
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var showInDock = DockIconVisibilityService.isVisible
    @State private var errorMessage: String?

    /// Fixed size, so the window never grows past a small screen. Long panes scroll.
    private static let windowSize = CGSize(width: 660, height: 460)
    private static let sidebarWidth: CGFloat = 180

    private var pane: SettingsPane {
        SettingsPane(rawValue: storedPane) ?? .general
    }

    private var paneSelection: Binding<SettingsPane?> {
        Binding(
            get: { pane },
            set: { if let newValue = $0 { storedPane = newValue.rawValue } }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .navigationTitle(pane.title)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            // With the trial ended, the license key is what the user came for.
            if !license.hasAccess {
                storedPane = SettingsPane.license.rawValue
            }
            refresh()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: paneSelection) {
            ForEach(SettingsPane.allCases) { item in
                Label {
                    Text(item.title)
                } icon: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .tag(item)
            }
        }
        .listStyle(.sidebar)
        .frame(width: Self.sidebarWidth)
        .safeAreaInset(edge: .bottom) {
            Text(versionText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Panes

    @ViewBuilder
    private var detail: some View {
        switch pane {
        case .general: generalPane
        case .shortcuts: shortcutsPane
        case .displays: displaysPane
        case .keepOpen: keepOpenPane
        case .license: licensePane
        case .data: dataPane
        #if DEBUG
        case .developer: developerPane
        #endif
        }
    }

    private var generalPane: some View {
        Form {
            Section {
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
            } header: {
                Text("Startup")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show Docksly in Dock", isOn: showInDockBinding)
                    Text(showInDock
                        ? "Shows while a Docksly window is open. Docksly stays in the menu bar after you close it."
                        : "Docksly stays in the menu bar only.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("App Icon")
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsPane: some View {
        Form {
            Section {
                ForEach(store.library.profiles) { profile in
                    HStack {
                        Label {
                            Text(profile.name)
                                .lineLimit(1)
                        } icon: {
                            ColorDot(color: profile.color.color, diameter: 8)
                        }
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .dock(profile.id))
                    }
                }
                HStack {
                    Text("Switch to Next Dock")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .nextDock)
                }
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("Shortcuts work in any app.")
            }

            Section {
                Toggle("Show a notice when the dock changes", isOn: $showSwitchHUD)
                    .onChange(of: showSwitchHUD) { SwitchHUD.isEnabled = $0 }
            } footer: {
                Text("The notice shows after a switch from a shortcut, the Shortcuts app, a Focus, or a display change.")
            }
        }
        .formStyle(.grouped)
        .disabled(!license.hasAccess)
    }

    private var displaysPane: some View {
        Form {
            Section {
                LabeledContent("Connected") {
                    Text(DisplaySetKey.readableName(DisplayIdentity.current()))
                        .multilineTextAlignment(.trailing)
                }
                Picker("Dock", selection: $ruleDockID) {
                    ForEach(store.library.profiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                HStack {
                    Spacer()
                    Button("Use a Dock for This Display Setup") {
                        saveDisplayRule()
                    }
                    .disabled(ruleDockID == nil)
                }
            } header: {
                Text("This Display Setup")
            } footer: {
                Text("When this exact set of displays connects, Docksly uses its dock. A set with no rule changes nothing.")
            }

            Section {
                let rules = store.library.displayRules ?? []
                if rules.isEmpty {
                    Text("No display rules yet. Pick a dock above, then press Use a Dock for This Display Setup.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(rules) { rule in
                        HStack {
                            Text(rule.setName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(rule.setName)
                            Spacer()
                            Text(store.library.profile(id: rule.profileID)?.name ?? "Deleted dock")
                                .foregroundStyle(.secondary)
                            Button(role: .destructive) {
                                store.removeDisplayRule(id: rule.id)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove this rule")
                            .accessibilityLabel("Remove rule for \(rule.setName)")
                        }
                    }
                }
            } header: {
                Text("Rules")
            }
        }
        .formStyle(.grouped)
        .disabled(!license.hasAccess)
    }

    private var keepOpenPane: some View {
        Form {
            Section {
                let apps = store.library.alwaysKeepOpen ?? []
                if apps.isEmpty {
                    Text("No apps yet. Finder and Docksly are always kept.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(apps) { app in
                        HStack {
                            Text(app.name)
                            Spacer()
                            Button(role: .destructive) {
                                store.setAlwaysKeepOpen(apps.filter { $0 != app })
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Stop keeping this app open")
                            .accessibilityLabel("Stop keeping \(app.name) open")
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Add App…") {
                        addKeepOpenApp()
                    }
                }
            } header: {
                Text("Apps to Keep Open")
            } footer: {
                Text("A dock with Quit Apps Not in This Dock never quits these apps. Finder and Docksly are always kept.")
            }
        }
        .formStyle(.grouped)
        .disabled(!license.hasAccess)
    }

    private var licensePane: some View {
        Form {
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
                    Text("The trial starts the first time you open Docksly. After 7 days, enter a license key from Mayar. License checks use the Mayar service.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var dataPane: some View {
        Form {
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
                Text("Files")
            } footer: {
                Text("Docksly keeps your docks on this Mac. It saves the last 10 Dock backups.")
            }
        }
        .formStyle(.grouped)
    }

    #if DEBUG
    private var developerPane: some View {
        Form {
            Section {
                Button("Simulate trial ended") {
                    license.simulateTrialEnded()
                }
                Button("Restore local license") {
                    license.restoreLocalLicense()
                }
                .disabled(license.record.licenseCode.isEmpty)
            } header: {
                Text("License")
            } footer: {
                Text("Local only. These buttons do not call Mayar and do not use an activation slot.")
            }
        }
        .formStyle(.grouped)
    }
    #endif

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

    private func saveDisplayRule() {
        guard let ruleDockID else { return }
        let displays = DisplayIdentity.current()
        store.upsertDisplayRule(DisplayRule(
            setKey: DisplaySetKey.make(displays),
            setName: DisplaySetKey.readableName(displays),
            profileID: ruleDockID
        ))
        // Use the dock now, as the display rule would on a change.
        DockSwitcher.switchTo(profileID: ruleDockID, store: store)
    }

    private func addKeepOpenApp() {
        let panel = NSOpenPanel()
        panel.title = "Keep this app open"
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let id = DockApplicator.bundleIdentifier(at: url.path) else { return }
        let app = KeepOpenApp(bundleIdentifier: id, name: DockApplicator.displayName(at: url.path))
        let current = store.library.alwaysKeepOpen ?? []
        guard !current.contains(app) else { return }
        store.setAlwaysKeepOpen(current + [app])
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
        if ruleDockID == nil {
            ruleDockID = store.selectedProfileID
        }
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
