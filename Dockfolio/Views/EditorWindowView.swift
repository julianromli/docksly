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
        .frame(minWidth: 720, idealWidth: 780, maxWidth: 1100, minHeight: 268, idealHeight: 300)
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
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                ProfileIdentityEditor()
                Text(store.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.leading, 78)
            .background { WindowMoveBar() }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                ProfilePickerButton()
                addAppButton
                editMenu
                primaryAction
            }
            .padding(.trailing, 20)
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var addAppButton: some View {
        Button {
            store.wantsAddApp = true
        } label: {
            Label("Add", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .help("Add Application")
        .fixedSize()
    }

    private var editMenu: some View {
        Menu("Edit Dock") {
            Button("Add Application…") { store.wantsAddApp = true }
            Button("Add Spacer") { store.addSpacer() }
            Divider()
            Button("Capture Current Dock") { store.captureLiveDockIntoDraft() }
            Divider()
            Button("Export This Dock…") { exportSelected() }
            Button("Export All Docks…") { exportLibrary() }
            Button("Import Dock…") { importDock() }
            Divider()
            Button("Delete Dock…", role: .destructive) {
                showDeleteConfirm = true
            }
            .disabled(store.library.profiles.count < 2)
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .fixedSize()
    }

    @ViewBuilder
    private var primaryAction: some View {
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
        .padding(.horizontal, 22)
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
