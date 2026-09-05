import SwiftUI

struct DockStripView: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onAddApplication: () -> Void = {}

    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var consumedTranslation: CGFloat = 0
    @State private var renderedProfileID: UUID?

    private var itemSpacing: CGFloat { DockfolioStyle.itemSpacing }

    private var isSwitchingDock: Bool {
        guard let renderedProfileID else { return false }
        return renderedProfileID != store.selectedProfileID
    }

    var body: some View {
        Group {
            if store.draftItems.isEmpty {
                emptyState
            } else {
                strip
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: DockfolioStyle.shelfCorner, style: .continuous)
                .fill(DockfolioStyle.shelfFill)
        }
        .clipShape(RoundedRectangle(cornerRadius: DockfolioStyle.shelfCorner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DockfolioStyle.shelfCorner, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, DockfolioStyle.shelfHorizontal)
        .padding(.bottom, DockfolioStyle.shelfBottom)
        .onAppear {
            if renderedProfileID == nil {
                renderedProfileID = store.selectedProfileID
            }
        }
        .onChange(of: store.selectedProfileID) { newID in
            resetDrag()
            renderedProfileID = newID
        }
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
            HStack(spacing: 8) {
                Button("Add Application…", action: onAddApplication)
                    .buttonStyle(QuietCapsuleButtonStyle())
                Button("Add Spacer") { store.addSpacer() }
                    .buttonStyle(QuietCapsuleButtonStyle())
            }
        }
        .padding(.horizontal, DockfolioStyle.shelfInner)
        .padding(.vertical, DockfolioStyle.shelfInner)
        .frame(maxWidth: .infinity, minHeight: DockfolioStyle.emptyStripMinHeight)
    }

    private var stripContentWidth: CGFloat {
        let tiles = store.draftItems.reduce(CGFloat(0)) { $0 + tileWidth($1) }
        let gaps = CGFloat(store.draftItems.count) * itemSpacing
        return tiles + gaps + 52
    }

    private var strip: some View {
        GeometryReader { geo in
            let overflows = stripContentWidth + (DockfolioStyle.shelfInner * 2) > geo.size.width
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
                        .modifier(DockSwitchStagger(
                            index: index,
                            playEnter: isSwitchingDock && !reduceMotion,
                            profileID: store.selectedProfileID,
                            restaggerOnProfileChange: false,
                            reduceMotion: reduceMotion
                        ))
                    }

                    addTile
                        .modifier(DockSwitchStagger(
                            index: store.draftItems.count,
                            playEnter: isSwitchingDock && !reduceMotion,
                            profileID: store.selectedProfileID,
                            restaggerOnProfileChange: true,
                            reduceMotion: reduceMotion
                        ))
                }
                .padding(.vertical, DockfolioStyle.shelfInner)
                .padding(.leading, DockfolioStyle.shelfInner)
                .padding(.trailing, overflows ? DockfolioStyle.overflowPeek : DockfolioStyle.shelfInner)
                .animation(
                    (draggingID == nil && !reduceMotion && !isSwitchingDock)
                        ? DockfolioStyle.defaultSpring
                        : nil,
                    value: store.draftItems.map(\.id)
                )
            }
            .overlay(alignment: .trailing) {
                if overflows {
                    LinearGradient(
                        colors: [DockfolioStyle.shelfFill.opacity(0), DockfolioStyle.shelfFill],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: DockfolioStyle.overflowPeek)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(height: DockfolioStyle.tileRowHeight + (DockfolioStyle.shelfInner * 2))
    }

    private var addTile: some View {
        Button(action: onAddApplication) {
            ZStack {
                RoundedRectangle(cornerRadius: DockfolioStyle.addTileCorner, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
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

private struct DockSwitchStagger: ViewModifier {
    let index: Int
    let playEnter: Bool
    let profileID: UUID
    let restaggerOnProfileChange: Bool
    let reduceMotion: Bool

    @State private var visible: Bool
    @State private var hasAppeared = false

    init(
        index: Int,
        playEnter: Bool,
        profileID: UUID,
        restaggerOnProfileChange: Bool,
        reduceMotion: Bool
    ) {
        self.index = index
        self.playEnter = playEnter
        self.profileID = profileID
        self.restaggerOnProfileChange = restaggerOnProfileChange
        self.reduceMotion = reduceMotion
        _visible = State(initialValue: !playEnter)
    }

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
            .blur(radius: visible ? 0 : 4)
            .onAppear {
                reveal(animated: playEnter && !reduceMotion)
                hasAppeared = true
            }
            .onChange(of: profileID) { _ in
                guard hasAppeared, restaggerOnProfileChange else { return }
                reveal(animated: !reduceMotion)
            }
    }

    private func reveal(animated: Bool) {
        if !animated {
            visible = true
            return
        }
        visible = false
        let delay = min(Double(index) * DockfolioStyle.staggerStep, DockfolioStyle.staggerCap)
        withAnimation(DockfolioStyle.defaultSpring.delay(delay)) {
            visible = true
        }
    }
}
