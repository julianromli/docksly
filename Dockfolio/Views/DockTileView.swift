import SwiftUI
import AppKit

struct DockTileView: View {
    let item: DockItem
    var isDragging: Bool
    var onRemove: () -> Void
    var onMoveLeft: (() -> Void)?
    var onMoveRight: (() -> Void)?
    var onDragChanged: ((DragGesture.Value) -> Void)?
    var onDragEnded: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var allowsChromeMotion = false

    private var showRemove: Bool { isHovering && !isDragging }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            tile
                .scaleEffect(liftScale)
                .animation(reduceMotion ? nil : DockfolioStyle.defaultSpring, value: liftScale)
                .gesture(reorderGesture)
                .onHover { hovering in
                    isHovering = hovering
                    if hovering {
                        NSCursor.openHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
                .contextMenu {
                    if let onMoveLeft {
                        Button("Move Left", action: onMoveLeft)
                    }
                    if let onMoveRight {
                        Button("Move Right", action: onMoveRight)
                    }
                    if onMoveLeft != nil || onMoveRight != nil {
                        Divider()
                    }
                    Button("Remove", role: .destructive, action: onRemove)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.title)
                .accessibilityHint("Drag to reorder")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Remove", onRemove)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.primary, Color.primary.opacity(0.18))
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(PressableButtonStyle())
            .offset(x: 5, y: -5)
            .zIndex(2)
            .help("Remove")
            .accessibilityLabel("Remove \(item.title)")
            .contextualIconChrome(visible: showRemove, animated: allowsChromeMotion && !reduceMotion)
            .allowsHitTesting(showRemove)
            .accessibilityHidden(!showRemove)
        }
        .onAppear {
            DispatchQueue.main.async {
                allowsChromeMotion = true
            }
        }
    }

    private var liftScale: CGFloat {
        if reduceMotion { return 1 }
        if isDragging { return DockfolioStyle.dragScale }
        if isHovering && item.kind == .application { return DockfolioStyle.hoverScale }
        return 1
    }

    @ViewBuilder
    private var tile: some View {
        switch item.kind {
        case .application:
            applicationTile
        case .spacer:
            spacerTile
        }
    }

    private var reorderGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                NSCursor.closedHand.set()
                onDragChanged?(value)
            }
            .onEnded { _ in
                NSCursor.arrow.set()
                onDragEnded?()
            }
    }

    private var applicationTile: some View {
        let image = AppIconService.shared.icon(for: item)
        let missing = !AppIconService.shared.isResolvable(item)

        return ZStack(alignment: .bottomTrailing) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: DockfolioStyle.iconSize, height: DockfolioStyle.iconSize)
                .opacity(missing ? 0.55 : 1)

            if missing {
                Image(systemName: "exclamationmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 12))
                    .offset(x: 4, y: 4)
                    .accessibilityLabel("Application is missing")
            }
        }
        .frame(width: DockfolioStyle.tileWidth, height: 60)
        .help(missing ? "\(item.title) — missing on this Mac. Hover for Remove." : "\(item.title). Drag to reorder.")
    }

    private var spacerTile: some View {
        Capsule()
            .fill(Color.primary.opacity(isHovering ? 0.34 : 0.20))
            .animation(reduceMotion ? nil : DockfolioStyle.chromeFade, value: isHovering)
            .frame(width: 4, height: 36)
            .frame(width: DockfolioStyle.spacerWidth, height: 60)
            .contentShape(Rectangle())
            .help("Spacer. Drag to reorder.")
    }
}
