import SwiftUI

struct DockStripView: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onAddApplication: () -> Void = {}

    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var consumedTranslation: CGFloat = 0

    private var itemSpacing: CGFloat { DockfolioStyle.itemSpacing }

    var body: some View {
        Group {
            if store.draftItems.isEmpty {
                emptyState
            } else {
                strip
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.15) : DockfolioStyle.defaultSpring,
            value: store.selectedProfileID
        )
        .frame(maxWidth: .infinity, minHeight: 128)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background {
            VisualEffectBackground(material: .headerView, blendingMode: .withinWindow)
        }
        .clipShape(RoundedRectangle(cornerRadius: DockfolioStyle.shelfCorner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DockfolioStyle.shelfCorner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.38))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, DockfolioStyle.shelfHorizontal)
        .padding(.bottom, DockfolioStyle.shelfBottom)
        .onChange(of: store.selectedProfileID) { _ in
            resetDrag()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("This dock has no pinned apps")
                .font(.headline)
                .textCase(nil)
            Text("Add an application or a spacer to start this layout.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button("Add Application…", action: onAddApplication)
                    .buttonStyle(QuietCapsuleButtonStyle())
                Button("Add Spacer") { store.addSpacer() }
                    .buttonStyle(QuietCapsuleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128)
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: itemSpacing) {
                ForEach(Array(store.draftItems.enumerated()), id: \.element.id) { index, item in
                    DockTileView(
                        item: item,
                        isDragging: draggingID == item.id,
                        onRemove: { store.removeItem(id: item.id) },
                        onMoveLeft: index > 0 ? { store.moveItem(id: item.id, toIndex: index - 1) } : nil,
                        onMoveRight: index < store.draftItems.count - 1
                            ? { store.moveItem(id: item.id, toIndex: index + 1) }
                            : nil,
                        onDragChanged: { value in handleDrag(item, value) },
                        onDragEnded: {
                            withAnimation(reduceMotion ? nil : DockfolioStyle.flickSpring) {
                                resetDrag()
                            }
                        }
                    )
                    .offset(x: draggingID == item.id ? dragTranslation : 0)
                    .zIndex(draggingID == item.id ? 1 : 0)
                }

                addTile
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .animation(
                (draggingID == nil && !reduceMotion) ? DockfolioStyle.defaultSpring : nil,
                value: store.draftItems.map(\.id)
            )
        }
    }

    private var addTile: some View {
        Button(action: onAddApplication) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(SquareAddTileStyle())
        .help("Add Application")
        .accessibilityLabel("Add Application")
    }

    private func handleDrag(_ item: DockItem, _ value: DragGesture.Value) {
        if draggingID != item.id {
            draggingID = item.id
            consumedTranslation = 0
        }
        guard let from = store.draftItems.firstIndex(where: { $0.id == item.id }) else { return }
        let items = store.draftItems
        let effective = value.translation.width - consumedTranslation

        if effective > 0, from + 1 < items.count {
            let threshold = swapThreshold(current: items[from], neighbor: items[from + 1])
            if effective > threshold {
                store.moveItem(id: item.id, toIndex: from + 1)
                consumedTranslation += tileWidth(items[from + 1]) + itemSpacing
            }
        } else if effective < 0, from > 0 {
            let threshold = swapThreshold(current: items[from], neighbor: items[from - 1])
            if effective < -threshold {
                store.moveItem(id: item.id, toIndex: from - 1)
                consumedTranslation -= tileWidth(items[from - 1]) + itemSpacing
            }
        }

        dragTranslation = value.translation.width - consumedTranslation
    }

    private func swapThreshold(current: DockItem, neighbor: DockItem) -> CGFloat {
        let gap = (tileWidth(current) + tileWidth(neighbor)) / 2 + itemSpacing
        return gap * CGFloat(0.55)
    }

    private func resetDrag() {
        draggingID = nil
        dragTranslation = 0
        consumedTranslation = 0
    }

    private func tileWidth(_ item: DockItem) -> CGFloat {
        item.kind == .spacer ? DockfolioStyle.spacerWidth : DockfolioStyle.tileWidth
    }
}

private struct SquareAddTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? DockfolioStyle.pressScale : 1)
            .animation(DockfolioStyle.pressSpring, value: configuration.isPressed)
    }
}
