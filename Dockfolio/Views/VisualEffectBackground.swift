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

/// Makes the SwiftUI window glassy and keeps the traffic lights visible.
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

        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        } else {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        window.invalidateShadow()
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
    static let windowMinHeight: CGFloat = 300
    static let windowIdealHeight: CGFloat = 340

    static let trafficLightInset: CGFloat = 78
    static let headerTop: CGFloat = 18
    static let headerBottom: CGFloat = 8
    static let trailingInset: CGFloat = 20
    static let shelfHorizontal: CGFloat = 20
    static let shelfBottom: CGFloat = 18
    static let shelfCorner: CGFloat = 22

    static let iconSize: CGFloat = 52
    static let tileWidth: CGFloat = 56
    static let spacerWidth: CGFloat = 28
    static let itemSpacing: CGFloat = 8

    static let hoverScale: CGFloat = 1.12
    static let dragScale: CGFloat = 1.16
    static let pressScale: CGFloat = 0.97

    static let defaultSpring = Animation.spring(response: 0.35, dampingFraction: 1.0)
    static let flickSpring = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let pressSpring = Animation.spring(response: 0.22, dampingFraction: 1.0)
}
