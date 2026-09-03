import SwiftUI

struct DockTileView: View {
    let item: DockItem
    var isDragging: Bool
    var onRemove: () -> Void
    var onMoveLeft: (() -> Void)?
    var onMoveRight: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Group {
            switch item.kind {
            case .application:
                applicationTile
            case .spacer:
                spacerTile
            }
        }
        .opacity(isDragging ? 0.35 : 1)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            if item.kind == .spacer {
                if let onMoveLeft {
                    Button("Move Left", action: onMoveLeft)
                }
                if let onMoveRight {
                    Button("Move Right", action: onMoveRight)
                }
                Divider()
                Button("Remove", role: .destructive, action: onRemove)
            } else {
                Button("Remove", role: .destructive, action: onRemove)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(.isButton)
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
        .help(missing ? "\(item.title) — missing on this Mac" : item.title)
        .scaleEffect((!reduceMotion && isHovering) ? 1.06 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
    }

    private var spacerTile: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.primary.opacity(isHovering ? 0.28 : 0.16))
            .frame(width: 8, height: 40)
            .padding(.horizontal, 8)
            .frame(width: 28, height: 56)
            .contentShape(Rectangle())
            .help("Spacer")
    }
}
