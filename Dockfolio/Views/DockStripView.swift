import SwiftUI
import UniformTypeIdentifiers

struct DockStripView: View {
    @EnvironmentObject private var store: DockStore
    @State private var draggingID: UUID?

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
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("This dock has no pinned apps")
                .font(.headline)
                .textCase(nil)
            Text("Add an application or a spacer to start this layout.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 112)
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(store.draftItems.enumerated()), id: \.element.id) { index, item in
                    DockTileView(
                        item: item,
                        isDragging: draggingID == item.id,
                        onRemove: { store.removeItem(id: item.id) },
                        onMoveLeft: index > 0 ? { store.moveSpacer(id: item.id, by: -1) } : nil,
                        onMoveRight: index < store.draftItems.count - 1
                            ? { store.moveSpacer(id: item.id, by: 1) }
                            : nil
                    )
                    .onDrag {
                        draggingID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.plainText],
                        delegate: TileReorderDropDelegate(
                            itemID: item.id,
                            draggingID: $draggingID,
                            onMove: { source, target in
                                store.moveItem(id: source, to: target)
                            }
                        )
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }
}

private struct TileReorderDropDelegate: DropDelegate {
    let itemID: UUID
    @Binding var draggingID: UUID?
    let onMove: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != itemID else { return }
        onMove(draggingID, itemID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropExited(info: DropInfo) {}
}
