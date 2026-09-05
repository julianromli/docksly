import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditorWindowView: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var showImportError = false
    @State private var importError = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            DockStripView(onAddApplication: { store.wantsAddApp = true })
            errorSlot
        }
        .frame(
            minWidth: DockslyStyle.windowMinWidth,
            idealWidth: DockslyStyle.windowIdealWidth,
            maxWidth: DockslyStyle.windowMaxWidth
        )
        .background(DockslyStyle.windowFill(colorScheme))
        .background(WindowConfigurator())
        .onChange(of: store.lastError) { message in
            if let message {
                DockslyStyle.announce(message)
            }
        }
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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: DockslyStyle.trafficLightClearance)
                    .allowsHitTesting(false)
                WindowMoveBar()
                    .accessibilityHidden(true)
            }
            .frame(height: DockslyStyle.headerTop)

            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    ProfileIdentityEditor()
                    ProfilePickerButton()
                }
                .padding(.leading, DockslyStyle.contentLeading)

                WindowMoveBar()
                    .frame(minWidth: 12, maxWidth: .infinity)
                    .frame(height: 28)
                    .layoutPriority(-1)
                    .accessibilityHidden(true)

                HStack(spacing: 8) {
                    statusChip
                    overflowMenu
                    primaryAction
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .padding(.trailing, DockslyStyle.trailingInset)
            }
            .padding(.bottom, DockslyStyle.headerBottom)
        }
    }

    private var statusChip: some View {
        Text(store.statusText)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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
            return DockslyStyle.statusDirtyForeground(colorScheme)
        }
        if store.isSelectedCurrent {
            return DockslyStyle.statusCurrentForeground(colorScheme)
        }
        return Color.secondary
    }

    private var chipFill: Color {
        if store.isApplying {
            return DockslyStyle.statusNeutralFill(colorScheme)
        }
        if store.isDirty {
            return DockslyStyle.statusTint(
                DockslyStyle.statusDirtyForeground(colorScheme),
                scheme: colorScheme
            )
        }
        if store.isSelectedCurrent {
            return DockslyStyle.statusTint(
                DockslyStyle.statusCurrentForeground(colorScheme),
                scheme: colorScheme
            )
        }
        return DockslyStyle.statusNeutralFill(colorScheme)
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
            EmptyView()
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
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var errorSlot: some View {
        VStack(spacing: 0) {
            if let lastError = store.lastError {
                errorBar(lastError)
                    .transition(errorTransition)
            }
        }
        .animation(errorAnimation, value: store.lastError)
    }

    private var errorTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -12)),
            removal: .opacity.combined(with: .offset(y: -12))
        )
    }

    private var errorAnimation: Animation? {
        if reduceMotion { return nil }
        return store.lastError == nil ? DockslyStyle.errorExit : DockslyStyle.errorEnter
    }

    private func errorBar(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.callout)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)

            Spacer()
            Button("Dismiss") { store.clearError() }
                .buttonStyle(PressableButtonStyle())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DockslyStyle.shelfHorizontal)
        .padding(.vertical, 10)
        .background(DockslyStyle.errorFill(colorScheme))
    }

    private func exportSelected() {
        let panel = NSSavePanel()
        panel.title = "Export this dock"
        panel.nameFieldStringValue = "\(store.draftName).docksly.json"
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
        panel.nameFieldStringValue = "Docksly-library.json"
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
        AccentCapsuleLabel(configuration: configuration)
    }
}

private struct AccentCapsuleLabel: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.82 : 1))
            }
            .scaleEffect(pressScale)
            .animation(reduceMotion ? nil : DockslyStyle.pressSpring, value: configuration.isPressed)
            .dockslyFocusRing(isFocused: isFocused, shape: .capsule, color: .primary)
    }

    private var pressScale: CGFloat {
        if reduceMotion { return 1 }
        return configuration.isPressed ? DockslyStyle.pressScale : 1
    }
}

struct QuietCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietCapsuleLabel(isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

private struct QuietCapsuleLabel<Label: View>: View {
    var isPressed: Bool
    @ViewBuilder var label: Label

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        label
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(isPressed ? 0.12 : 0.06))
                    .shadow(color: liftShadow, radius: colorScheme == .dark ? 0 : 1, x: 0, y: 1)
                    .shadow(color: ambientShadow, radius: colorScheme == .dark ? 0 : 2, x: 0, y: 2)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(ringColor, lineWidth: 1)
                    .animation(reduceMotion ? nil : DockslyStyle.chromeFade, value: isHovering)
            }
            .scaleEffect(pressScale)
            .animation(reduceMotion ? nil : DockslyStyle.pressSpring, value: isPressed)
            .dockslyFocusRing(isFocused: isFocused, shape: .capsule)
            .onHover { isHovering = $0 }
    }

    private var pressScale: CGFloat {
        if reduceMotion { return 1 }
        return isPressed ? DockslyStyle.pressScale : 1
    }

    private var ringColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(isHovering ? 0.13 : 0.08)
        }
        return Color.black.opacity(isHovering ? 0.08 : 0.06)
    }

    private var liftShadow: Color {
        colorScheme == .dark ? .clear : Color.black.opacity(isHovering ? 0.08 : 0.06)
    }

    private var ambientShadow: Color {
        colorScheme == .dark ? .clear : Color.black.opacity(isHovering ? 0.06 : 0.04)
    }
}
