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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            tile
                .opacity(isDragging ? 0.92 : 1)
                .scaleEffect((isDragging && !reduceMotion) ? 1.08 : 1)
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

            if isHovering && !isDragging {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.red)
                        .font(.system(size: 14, weight: .semibold))
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
                .help("Remove")
                .accessibilityLabel("Remove \(item.title)")
            }
        }
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
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        .padding(-1)
                }
                .opacity(missing ? 0.55 : 1)

            if missing {
                Image(systemName: "exclamationmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 12))
                    .offset(x: 4, y: 4)
                    .accessibilityLabel("Application is missing")
            }
        }
        .frame(width: 52, height: 56)
        .help(missing ? "\(item.title) — missing on this Mac. Hover for Remove." : "\(item.title). Drag to reorder.")
        .scaleEffect((!reduceMotion && isHovering && !isDragging) ? 1.06 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
    }

    private var spacerTile: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.primary.opacity(isHovering ? 0.28 : 0.16))
            .frame(width: 8, height: 40)
            .padding(.horizontal, 8)
            .frame(width: 28, height: 56)
            .contentShape(Rectangle())
            .help("Spacer. Drag to reorder.")
    }
}
