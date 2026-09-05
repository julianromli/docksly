import SwiftUI
import AppKit

struct DockTileView: View {
    let item: DockItem
    var isDragging: Bool
    var isPlaceholder: Bool = false
    var isReordering: Bool = false
    var onRemove: () -> Void
    var onMoveLeft: (() -> Void)?
    var onMoveRight: (() -> Void)?
    var onDragChanged: ((DragGesture.Value) -> Void)?
    var onDragEnded: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHoveringTile = false
    @State private var isHoveringRemove = false
    @State private var allowsChromeMotion = false

    private var isHovering: Bool { isHoveringTile || isHoveringRemove }
    private var showRemove: Bool { isHovering && !isDragging && !isReordering }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            tile
                .scaleEffect(liftScale)
                .animation(
                    (reduceMotion || isReordering) ? nil : DockfolioStyle.defaultSpring,
                    value: liftScale
                )
                .highPriorityGesture(reorderGesture)
                .onHover { hovering in
                    isHoveringTile = hovering
                    updateCursor(overTile: hovering, overRemove: isHoveringRemove)
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
                .accessibilityHidden(isPlaceholder)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.primary, Color.primary.opacity(0.18))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(
                        width: DockfolioStyle.removeHitSize,
                        height: DockfolioStyle.removeHitSize,
                        alignment: .topTrailing
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .offset(x: 5, y: -5)
            .zIndex(2)
            .help("Remove")
            .accessibilityLabel("Remove \(item.title)")
            .onHover { hovering in
                isHoveringRemove = hovering
                updateCursor(overTile: isHoveringTile, overRemove: hovering)
            }
            .contextualIconChrome(visible: showRemove, animated: allowsChromeMotion && !reduceMotion)
            .allowsHitTesting(showRemove)
            .accessibilityHidden(!showRemove)
        }
        .opacity(isPlaceholder ? 0 : 1)
        .onAppear {
            DispatchQueue.main.async {
                allowsChromeMotion = true
            }
        }
    }

    private func updateCursor(overTile: Bool, overRemove: Bool) {
        if isDragging || isReordering {
            NSCursor.closedHand.set()
            return
        }
        if overRemove {
            NSCursor.arrow.set()
        } else if overTile {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private var liftScale: CGFloat {
        if reduceMotion { return 1 }
        if isDragging { return DockfolioStyle.dragScale }
        if isReordering { return 1 }
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
        DragGesture(minimumDistance: 6, coordinateSpace: .named(DockfolioStyle.dockStripSpace))
            .onChanged { value in
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
