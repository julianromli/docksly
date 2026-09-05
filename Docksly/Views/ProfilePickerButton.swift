import AppKit
import SwiftUI

struct ProfilePickerButton: View {
    @EnvironmentObject private var store: DockStore
    @State private var newName = ""

    var body: some View {
        Menu {
            ForEach(store.library.profiles) { profile in
                Button {
                    store.select(profileID: profile.id)
                } label: {
                    HStack {
                        if store.library.activeProfileID == profile.id {
                            Image(systemName: "checkmark")
                        }
                        Label {
                            Text(profile.name)
                        } icon: {
                            ColorDot(color: profile.color.color, diameter: 8)
                        }
                    }
                }
            }
            Divider()
            Button("New Dock…") {
                store.wantsNewDockName = true
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel("Switch Dock")
        .alert("New Dock", isPresented: $store.wantsNewDockName) {
            TextField("Name", text: $newName)
            Button("Create Dock") {
                store.createDock(named: newName)
                newName = ""
            }
            Button("Cancel", role: .cancel) {
                newName = ""
            }
        } message: {
            Text("Give this setup a name. Docksly copies the items you see now.")
        }
    }
}

struct ProfileIdentityEditor: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showColors = false
    @State private var allowsSwatchMotion = false
    @State private var nameAtEditStart = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showColors.toggle()
            } label: {
                ColorDot(color: store.draftColor.color, diameter: 14)
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle(focusShape: .circle))
            .help("Change dock color")
            .accessibilityLabel("Dock color, \(store.draftColor.displayName)")
            .popover(isPresented: $showColors, arrowEdge: .bottom) {
                colorSwatches
                    .padding(10)
                    .onAppear {
                        DispatchQueue.main.async {
                            allowsSwatchMotion = true
                        }
                    }
                    .onDisappear {
                        allowsSwatchMotion = false
                    }
            }

            TextField("Dock name", text: Binding(
                get: { store.draftName },
                set: { store.renameDraft($0) }
            ))
            .textFieldStyle(.plain)
            .font(.title3.weight(.semibold))
            .tracking(-0.015)
            .autocorrectionDisabled(true)
            .lineLimit(1)
            .frame(minWidth: 72, maxWidth: 240, alignment: .leading)
            .layoutPriority(0)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(nameFocused ? 0.08 : 0))
                    .animation(reduceMotion ? nil : DockslyStyle.chromeFade, value: nameFocused)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .focused($nameFocused)
            .accessibilityLabel("Dock name")
            .help(store.draftName)
            .background(QuietTitleFieldTuning())
            .onSubmit {
                store.commitDraftName()
                nameAtEditStart = store.draftName
            }
            .onExitCommand {
                store.renameDraft(nameAtEditStart)
                nameFocused = false
            }
            .onChange(of: nameFocused) { focused in
                if focused {
                    nameAtEditStart = store.draftName
                } else {
                    store.commitDraftName()
                }
            }
            .onAppear {
                nameAtEditStart = store.draftName
            }
        }
    }

    private var colorSwatches: some View {
        HStack(spacing: 8) {
            ForEach(ProfileColor.palette) { color in
                let selected = store.draftColor == color
                Button {
                    store.setDraftColor(color)
                    showColors = false
                } label: {
                    ZStack {
                        ColorDot(color: color.color, diameter: 20)
                        if selected {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 2)
                                .frame(width: 24, height: 24)
                        }
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(color.markColor)
                            .contextualIconChrome(
                                visible: selected,
                                animated: allowsSwatchMotion && !reduceMotion
                            )
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle(focusShape: .circle))
                .help(color.displayName)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Turns off AppKit spellcheck and substitutions on the title field.
private struct QuietTitleFieldTuning: NSViewRepresentable {
    func makeNSView(context: Context) -> QuietTitleFieldTuningView {
        QuietTitleFieldTuningView()
    }

    func updateNSView(_ nsView: QuietTitleFieldTuningView, context: Context) {
        nsView.quietNearbyField()
    }
}

private final class QuietTitleFieldTuningView: NSView {
    private var observer: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        observer = NotificationCenter.default.addObserver(
            forName: NSControl.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let field = notification.object as? NSTextField else { return }
            guard self.nearestTextField() === field else { return }
            Self.quiet(field)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        quietNearbyField()
    }

    func quietNearbyField() {
        if let field = nearestTextField() {
            Self.quiet(field)
        }
    }

    private func nearestTextField() -> NSTextField? {
        var node: NSView? = self
        while let current = node {
            if let field = current as? NSTextField {
                return field
            }
            if let parent = current.superview {
                if let field = parent as? NSTextField {
                    return field
                }
                for sibling in parent.subviews where sibling !== current {
                    if let field = Self.findTextField(in: sibling) {
                        return field
                    }
                }
            }
            node = current.superview
        }
        return nil
    }

    private static func findTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField {
            return field
        }
        for child in view.subviews {
            if let field = findTextField(in: child) {
                return field
            }
        }
        return nil
    }

    private static func quiet(_ field: NSTextField) {
        field.isAutomaticTextCompletionEnabled = false
        guard let editor = field.currentEditor() as? NSTextView else { return }
        editor.isContinuousSpellCheckingEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextCompletionEnabled = false
    }
}
