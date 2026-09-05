import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditorWindowView: View {
    @EnvironmentObject private var store: DockStore
    @State private var showImportError = false
    @State private var importError = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            DockStripView(onAddApplication: { store.wantsAddApp = true })
            if let lastError = store.lastError {
                errorBar(lastError)
            }
        }
        .frame(
            minWidth: DockfolioStyle.windowMinWidth,
            idealWidth: DockfolioStyle.windowIdealWidth,
            maxWidth: DockfolioStyle.windowMaxWidth,
            minHeight: DockfolioStyle.windowMinHeight,
            idealHeight: DockfolioStyle.windowIdealHeight
        )
        .background(VisualEffectBackground())
        .background(WindowConfigurator())
        .sheet(isPresented: $store.wantsAddApp) {
            AddAppSheet()
                .environmentObject(store)
        }
        .alert("Import failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError)
        }
        .alert("Delete this dock?", isPresented: $showDeleteConfirm) {
            Button("Delete Dock", role: .destructive) {
                store.deleteSelectedDock()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(store.draftName)” will be removed from this Mac. The real Dock does not change until you apply another setup.")
        }
        .onAppear {
            store.refreshLiveSignature()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification, object: nil)) { _ in
            if !store.isApplying { store.refreshLiveSignature() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                ProfileIdentityEditor()
                ProfilePickerButton()
            }
            .padding(.leading, DockfolioStyle.trafficLightInset)
            .background { WindowMoveBar() }

            statusChip

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                overflowMenu
                primaryAction
            }
            .padding(.trailing, DockfolioStyle.trailingInset)
        }
        .padding(.top, DockfolioStyle.headerTop)
        .padding(.bottom, DockfolioStyle.headerBottom)
    }

    private var statusChip: some View {
        Text(store.statusText)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(chipForeground)
            .background(Capsule(style: .continuous).fill(chipFill))
    }

    private var chipForeground: Color {
        if store.isApplying {
            return Color.secondary
        }
        if store.isDirty {
            return Color(red: 0.80, green: 0.47, blue: 0.04)
        }
        if store.isSelectedCurrent {
            return Color(red: 0.19, green: 0.66, blue: 0.32)
        }
        return Color.secondary
    }

    private var chipFill: Color {
        if store.isApplying {
            return Color.primary.opacity(0.08)
        }
        if store.isDirty {
            return Color(red: 0.80, green: 0.47, blue: 0.04).opacity(0.14)
        }
        if store.isSelectedCurrent {
            return Color(red: 0.19, green: 0.66, blue: 0.32).opacity(0.14)
        }
        return Color.primary.opacity(0.08)
    }

    private var overflowMenu: some View {
        Menu {
            Button("Add Application…") { store.wantsAddApp = true }
            Button("Add Spacer") { store.addSpacer() }
            Divider()
            Button("Capture Current Dock") { store.captureLiveDockIntoDraft() }
            Divider()
            Button("Export This Dock…") { exportSelected() }
            Button("Export All Docks…") { exportLibrary() }
            Button("Import Dock…") { importDock() }
            Divider()
            Button("Delete Dock…", role: .destructive) { showDeleteConfirm = true }
                .disabled(store.library.profiles.count < 2)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Edit Dock")
        .accessibilityLabel("Edit Dock")
    }

    @ViewBuilder
    private var primaryAction: some View {
        if store.isApplying {
            HStack(spacing: 8) {
                if store.isDirty {
                    Button {
                        store.saveDraft(applyIfActive: true)
                    } label: {
                        applyingLabel
                    }
                    .buttonStyle(AccentCapsuleButtonStyle())
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(true)
                }
                if !store.isSelectedCurrent && !(store.isSelectedActive && store.isDirty) {
                    Button {
                        store.applySelected(saveFirst: true)
                    } label: {
                        applyingLabel
                    }
                    .buttonStyle(AccentCapsuleButtonStyle())
                    .disabled(true)
                }
            }
        } else if store.isSelectedCurrent && !store.isDirty {
            Label("On Dock", systemImage: "checkmark")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 8) {
                if store.isDirty {
                    Button("Save Changes") {
                        store.saveDraft(applyIfActive: true)
                    }
                    .buttonStyle(AccentCapsuleButtonStyle())
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(store.isApplying)
                }
                if !store.isSelectedCurrent && !(store.isSelectedActive && store.isDirty) {
                    Button("Use This Dock") {
                        store.applySelected(saveFirst: true)
                    }
                    .buttonStyle(AccentCapsuleButtonStyle())
                    .disabled(store.isApplying)
                }
            }
        }
    }

    private var applyingLabel: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Applying…")
        }
    }

    private func errorBar(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
            Text(message)
                .font(.callout)
                .textSelection(.enabled)
            Spacer()
            Button("Dismiss") { store.clearError() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DockfolioStyle.shelfHorizontal)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.08))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private func exportSelected() {
        let panel = NSSavePanel()
        panel.title = "Export this dock"
        panel.nameFieldStringValue = "\(store.draftName).dockfolio.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try store.exportSelectedDock(to: url)
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }

    private func exportLibrary() {
        let panel = NSSavePanel()
        panel.title = "Export all docks"
        panel.nameFieldStringValue = "Dockfolio-library.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try store.exportLibrary(to: url)
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }

    private func importDock() {
        let panel = NSOpenPanel()
        panel.title = "Import a dock"
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try store.import(from: url)
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }
}

struct AccentCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.82 : 1))
            }
            .scaleEffect(configuration.isPressed ? DockfolioStyle.pressScale : 1)
            .animation(DockfolioStyle.pressSpring, value: configuration.isPressed)
    }
}

struct QuietCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? DockfolioStyle.pressScale : 1)
            .animation(DockfolioStyle.pressSpring, value: configuration.isPressed)
    }
}
