import AppKit
import SwiftUI

/// A short notice in the lower center of the screen after a switch from a
/// hotkey, the Shortcuts app, or a Focus. It looks like the system volume HUD.
@MainActor
enum SwitchHUD {
    private static let enabledKey = "showSwitchHUD"
    private static let visibleDuration: TimeInterval = 1.1
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    /// Missing key means true.
    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static func show(_ profile: DockProfile) {
        guard isEnabled else { return }
        let panel = panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: SwitchHUDView(name: profile.name, color: profile.color.color))
        host.frame.size = host.fittingSize
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        position(panel)

        hideWork?.cancel()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !panel.isVisible {
            panel.alphaValue = reduceMotion ? 1 : 0
            panel.orderFrontRegardless()
        }
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
        }

        let work = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = reduceMotion ? 0 : 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor in
                    if panel.alphaValue == 0 { panel.orderOut(nil) }
                }
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration, execute: work)
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        return panel
    }

    /// Lower center of the screen with the pointer, above the Dock area.
    private static func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 96)
        panel.setFrameOrigin(origin)
    }
}

private struct SwitchHUDView: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ColorDot(color: color, diameter: 12)
            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minWidth: 140)
        .background {
            // Blur what is behind the panel, the same way the system HUD does.
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .padding(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dock changed to \(name)")
    }
}
