import SwiftUI
import AppKit
import KeyboardShortcuts

struct MenuBarContentView: View {
    @EnvironmentObject private var store: DockStore
    @EnvironmentObject private var license: LicenseStore
    @EnvironmentObject private var cleanUp: CleanUpController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if cleanUp.phase == .idle {
                menuList
            } else {
                CleanUpReviewView(layout: .popover)
            }
        }
        .frame(width: CleanUpStyle.popoverWidth)
        .padding(.vertical, 5)
        .background(VisualEffectBackground(material: .menu, blendingMode: .behindWindow))
        .animation(reduceMotion ? nil : CleanUpStyle.heightAnimation, value: cleanUp.phase)
        .onAppear { cleanUp.refresh() }
    }

    private var menuList: some View {
        VStack(spacing: 0) {
            ForEach(store.library.profiles) { profile in
                Button {
                    if profile.id == store.selectedProfileID {
                        store.applySelected(saveFirst: true)
                    } else {
                        store.apply(profileID: profile.id)
                    }
                    dismiss()
                } label: {
                    dockRow(profile)
                }
                .buttonStyle(MenuBarRowButtonStyle())
                .globalKeyboardShortcut(.dock(profile.id))
                .disabled(store.isApplying || !license.hasAccess)
                .accessibilityLabel(profile.name)
                .accessibilityValue(store.library.activeProfileID == profile.id ? "On Dock" : "")
            }

            menuDivider

            cleanUpRow

            menuDivider

            MenuBarRowButton("Save Current Dock as New Dock…", action: {
                dismiss()
                SaveLiveDockPrompt.run(store: store)
            })
            .disabled(!license.hasAccess)

            menuDivider

            MenuBarRowButton("Manage Docks…", action: {
                AppWindowPresentation.presentEditor(using: openWindow)
                dismiss()
            })

            MenuSettingsButton()
                .buttonStyle(MenuBarRowButtonStyle())

            menuDivider

            MenuBarRowButton("Quit Docksly", action: {
                NSApp.terminate(nil)
            })
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private var cleanUpRow: some View {
        Button {
            cleanUp.beginReview()
        } label: {
            HStack(spacing: 0) {
                Text("Clean Up")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                MenuBarTrailingCount(text: CleanUpCopy.countLabel(cleanUp.leftoverCount))
            }
        }
        .buttonStyle(MenuBarRowButtonStyle())
        .disabled(!cleanUp.canStartReview)
        .accessibilityLabel("Clean Up")
        .accessibilityValue(CleanUpCopy.countLabel(cleanUp.leftoverCount))
        .accessibilityHint(
            !license.hasAccess
                ? "Enter a license key to use Clean Up"
                : (cleanUp.hasLeftovers
                    ? "Reviews running apps that are not in the current dock"
                    : "No apps to clean up")
        )
    }

    private func dockRow(_ profile: DockProfile) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 16)
                .opacity(store.library.activeProfileID == profile.id ? 1 : 0)
                .accessibilityHidden(true)
            ColorDot(color: profile.color.color, diameter: 8)
            Text(profile.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var menuDivider: some View {
        Divider()
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
    }
}

private struct MenuBarRowButton: View {
    var title: String
    var action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MenuBarRowButtonStyle())
    }
}

private struct MenuBarRowHighlightedKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var menuBarRowHighlighted: Bool {
        get { self[MenuBarRowHighlightedKey.self] }
        set { self[MenuBarRowHighlightedKey.self] = newValue }
    }
}

private struct MenuBarTrailingCount: View {
    var text: String
    @Environment(\.menuBarRowHighlighted) private var highlighted

    var body: some View {
        Text(text)
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(highlighted ? Color.white.opacity(0.9) : Color.secondary)
    }
}

private struct MenuBarRowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let highlighted = isEnabled && (isHovering || configuration.isPressed)
        return configuration.label
            .environment(\.menuBarRowHighlighted, highlighted)
            .foregroundStyle(highlighted ? Color.white : Color.primary.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, 10)
            .frame(height: CleanUpStyle.menuRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(highlighted ? Color.accentColor : Color.clear)
                    .padding(.horizontal, 5)
            }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }
}

struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .accessibilityLabel("Docksly")
            .onReceive(NotificationCenter.default.publisher(for: .dockslyOpenEditor)) { _ in
                AppWindowPresentation.presentEditor(using: openWindow)
            }
    }
}
