import SwiftUI

struct DockStripView: View {
    @EnvironmentObject private var store: DockStore
    var onAddApplication: () -> Void = {}

    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var consumedTranslation: CGFloat = 0

    private let itemSpacing: CGFloat = 10

    var body: some View {
        Group {
            if store.draftItems.isEmpty {
                emptyState
            } else {
                strip
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
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
        .frame(maxWidth: .infinity, minHeight: 112)
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
                            withAnimation(.easeOut(duration: 0.16)) {
                                resetDrag()
                            }
                        }
                    )
                    .offset(x: draggingID == item.id ? dragTranslation : 0)
                    .zIndex(draggingID == item.id ? 1 : 0)
                }

                addTile
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    private var addTile: some View {
        Button(action: onAddApplication) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .foregroundStyle(Color.primary.opacity(0.28))
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    }
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                consumedTranslation += Self.tileWidth(items[from + 1]) + itemSpacing
            }
        } else if effective < 0, from > 0 {
            let threshold = swapThreshold(current: items[from], neighbor: items[from - 1])
            if effective < -threshold {
                store.moveItem(id: item.id, toIndex: from - 1)
                consumedTranslation -= Self.tileWidth(items[from - 1]) + itemSpacing
            }
        }

        dragTranslation = value.translation.width - consumedTranslation
    }

    private func swapThreshold(current: DockItem, neighbor: DockItem) -> CGFloat {
        let gap = (Self.tileWidth(current) + Self.tileWidth(neighbor)) / 2 + itemSpacing
        return gap * CGFloat(0.55)
    }


    private func resetDrag() {
        draggingID = nil
        dragTranslation = 0
        consumedTranslation = 0
    }

    private static func tileWidth(_ item: DockItem) -> CGFloat {
        item.kind == .spacer ? 28 : 52
    }
}
