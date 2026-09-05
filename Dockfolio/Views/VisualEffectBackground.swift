import AppKit
import SwiftUI

/// Full-window material so the chrome stays translucent behind the editor.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.isEmphasized = true
        context.coordinator.bind(view, material: material, blendingMode: blendingMode)
        Self.apply(to: view, material: material, blendingMode: blendingMode)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        context.coordinator.material = material
        context.coordinator.blendingMode = blendingMode
        Self.apply(to: nsView, material: material, blendingMode: blendingMode)
    }

    fileprivate static func apply(
        to view: NSVisualEffectView,
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode
    ) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            view.material = .windowBackground
        } else {
            view.material = material
        }
        view.blendingMode = blendingMode
    }

    final class Coordinator: NSObject {
        weak var view: NSVisualEffectView?
        var material: NSVisualEffectView.Material = .hudWindow
        var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

        func bind(
            _ view: NSVisualEffectView,
            material: NSVisualEffectView.Material,
            blendingMode: NSVisualEffectView.BlendingMode
        ) {
            self.view = view
            self.material = material
            self.blendingMode = blendingMode
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(optionsChanged(_:)),
                name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: NSWorkspace.shared
            )
        }

        @objc func optionsChanged(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                guard let self, let view = self.view else { return }
                VisualEffectBackground.apply(
                    to: view,
                    material: self.material,
                    blendingMode: self.blendingMode
                )
            }
        }

        deinit {
            NSWorkspace.shared.notificationCenter.removeObserver(self)
        }
    }
}

/// Opaque white chrome. The editor stays solid so a dark desktop cannot show through.
struct WindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.hostView = view
        context.coordinator.startObserving()
        DispatchQueue.main.async {
            Self.configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        DispatchQueue.main.async {
            Self.configure(nsView.window)
        }
    }

    static func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.titlebarSeparatorStyle = .none
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        window.appearance = NSAppearance(named: .aqua)
        window.isOpaque = true
        window.backgroundColor = NSColor(srgbRed: 245 / 255, green: 245 / 255, blue: 245 / 255, alpha: 1)
        window.invalidateShadow()
        compactRestoredFrameIfNeeded(window)
    }

    private static var didCompactRestoredFrame = false

    /// Saved frames from the taller glass window leave a gray floor. Shrink once.
    private static func compactRestoredFrameIfNeeded(_ window: NSWindow) {
        guard !didCompactRestoredFrame else { return }
        let target = DockfolioStyle.windowIdealHeight
        guard window.frame.height > target + 24 else {
            didCompactRestoredFrame = true
            return
        }
        didCompactRestoredFrame = true
        var frame = window.frame
        let delta = frame.height - target
        frame.size.height = target
        frame.origin.y += delta
        window.setFrame(frame, display: true)
    }

    final class Coordinator: NSObject {
        weak var hostView: NSView?

        func startObserving() {
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(optionsChanged(_:)),
                name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: NSWorkspace.shared
            )
        }

        @objc func optionsChanged(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                WindowConfigurator.configure(self?.hostView?.window)
            }
        }

        deinit {
            NSWorkspace.shared.notificationCenter.removeObserver(self)
        }
    }
}

/// Drag handle for the editor header. The window is not movable by background
/// so strip `DragGesture` can reorder tiles.
struct WindowMoveBar: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowMoveBarView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowMoveBarView: NSView {
    override var isOpaque: Bool { false }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

enum DockfolioStyle {
    static let windowMinWidth: CGFloat = 720
    static let windowIdealWidth: CGFloat = 780
    static let windowMaxWidth: CGFloat = 1100
    static let windowMinHeight: CGFloat = 152
    static let windowIdealHeight: CGFloat = 168

    static let headerTop: CGFloat = 30
    static let headerBottom: CGFloat = 8
    static let trailingInset: CGFloat = 12
    static let shelfHorizontal: CGFloat = 12
    static let shelfBottom: CGFloat = 12
    static let shelfInner: CGFloat = 8
    static let shelfCorner: CGFloat = 22
    /// Shared left rail: color, title, menu, status, and the first dock icon.
    static var contentLeading: CGFloat { shelfHorizontal + shelfInner }
    static let overflowPeek: CGFloat = 20
    static let emptyStripMinHeight: CGFloat = 96
    static let tileRowHeight: CGFloat = 60

    static let iconSize: CGFloat = 52
    static let tileWidth: CGFloat = 56
    /// Desktop hit target for the remove control. The glyph stays 13pt.
    static let removeHitSize: CGFloat = 40
    static let spacerWidth: CGFloat = 28
    static let itemSpacing: CGFloat = 8
    static let dockStripSpace = "dockStrip"

    static let hoverScale: CGFloat = 1.12
    static let dragScale: CGFloat = 1.16
    static let pressScale: CGFloat = 0.96
    static let addTileCorner: CGFloat = 14
    static let iconHiddenScale: CGFloat = 0.25
    static let iconHiddenBlur: CGFloat = 4
    static let staggerStep: Double = 0.1
    static let staggerCap: Double = 0.8

    static let defaultSpring = Animation.spring(response: 0.35, dampingFraction: 1.0)
    static let flickSpring = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let pressSpring = Animation.spring(response: 0.22, dampingFraction: 1.0)
    /// Contextual icon chrome: 300ms, no bounce.
    static let iconChromeSpring = Animation.spring(response: 0.3, dampingFraction: 1.0)
    static let errorEnter = Animation.easeOut(duration: 0.3)
    static let errorExit = Animation.easeOut(duration: 0.15)
    static let chromeFade = Animation.easeOut(duration: 0.15)

    static let windowFill = Color(hex: "F5F5F5")
    static let shelfFill = Color(hex: "F5F5F5")
}

/// Press scale of 0.96. Pass `isStatic: true` when motion would distract.
struct PressableButtonStyle: ButtonStyle {
    var isStatic: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect((!isStatic && configuration.isPressed) ? DockfolioStyle.pressScale : 1)
            .animation(DockfolioStyle.pressSpring, value: configuration.isPressed)
    }
}

extension View {
    /// Keep hover/state chrome in the tree and cross-fade it.
    func contextualIconChrome(visible: Bool, animated: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : DockfolioStyle.iconHiddenScale)
            .blur(radius: visible ? 0 : DockfolioStyle.iconHiddenBlur)
            .animation(animated ? DockfolioStyle.iconChromeSpring : nil, value: visible)
    }
}
