import AppKit
import SwiftUI

struct DockStripView: View {
    @EnvironmentObject private var store: DockStore
    @EnvironmentObject private var license: LicenseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    var onAddApplication: () -> Void = {}

    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragStartX: CGFloat = 0
    @State private var dragItems: [DockItem]?
    @State private var renderedProfileID: UUID?

    private var itemSpacing: CGFloat { DockslyStyle.itemSpacing }

    private var displayItems: [DockItem] {
        dragItems ?? store.draftItems
    }

    private var isSwitchingDock: Bool {
        guard let renderedProfileID else { return false }
        return renderedProfileID != store.selectedProfileID
    }

    var body: some View {
        Group {
            if store.draftItems.isEmpty && store.draftOthers.isEmpty {
                emptyState
            } else {
                strip
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: DockslyStyle.shelfCorner, style: .continuous)
                .fill(DockslyStyle.shelfFill(colorScheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: DockslyStyle.shelfCorner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DockslyStyle.shelfCorner, style: .continuous)
                .strokeBorder(DockslyStyle.shelfStroke(colorScheme), lineWidth: 1)
        }
        .padding(.horizontal, DockslyStyle.shelfHorizontal)
        .padding(.bottom, DockslyStyle.shelfBottom)
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
            Text(license.hasAccess
                ? "Add an application or a spacer to start this layout."
                : "Enter a license key to change this layout.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if license.hasAccess {
                HStack(spacing: 8) {
                    Button("Add Application…", action: onAddApplication)
                        .buttonStyle(QuietCapsuleButtonStyle())
                    Button("Add Spacer") { store.addSpacer() }
                        .buttonStyle(QuietCapsuleButtonStyle())
                    Button("Add Folder…") { DockStripView.addFolder(to: store) }
                        .buttonStyle(QuietCapsuleButtonStyle())
                }
            }
        }
        .padding(.horizontal, DockslyStyle.shelfInner)
        .padding(.vertical, DockslyStyle.shelfInner)
        .frame(maxWidth: .infinity, minHeight: DockslyStyle.emptyStripMinHeight)
    }

    private var stripContentWidth: CGFloat {
        let tiles = store.draftItems.reduce(CGFloat(0)) { $0 + tileWidth($1) }
        let gaps = CGFloat(store.draftItems.count + store.draftOthers.count + 2) * itemSpacing
        let others = CGFloat(store.draftOthers.count) * DockslyStyle.tileWidth
        return tiles + gaps + others + 52 + sideDividerWidth + 52
    }

    private let sideDividerWidth: CGFloat = 9

    private var strip: some View {
        GeometryReader { geo in
            let overflows = stripContentWidth + (DockslyStyle.shelfInner * 2) > geo.size.width
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        DockTileView(
                            item: item,
                            isDragging: false,
                            isPlaceholder: draggingID == item.id,
                            isReordering: draggingID != nil,
                            onRemove: { store.removeItem(id: item.id) },
                            onMoveLeft: license.hasAccess && index > 0
                                ? { store.moveItem(id: item.id, toIndex: index - 1) }
                                : nil,
                            onMoveRight: license.hasAccess && index < displayItems.count - 1
                                ? { store.moveItem(id: item.id, toIndex: index + 1) }
                                : nil,
                            onDragChanged: license.hasAccess
                                ? { value in handleDrag(item, value) }
                                : nil,
                            onDragEnded: license.hasAccess ? endDrag : nil,
                            allowsEditing: license.hasAccess,
                            onToggleOpen: license.hasAccess && item.kind == .application
                                ? { store.updateItem(id: item.id) { $0.opensWhenUsed = !($0.opensWhenUsed ?? false) } }
                                : nil,
                            onChooseOpenTarget: license.hasAccess && item.kind == .application
                                ? {
                                    if let target = SwitchActions.chooseOpenTarget() {
                                        store.updateItem(id: item.id) { $0.openTarget = target }
                                    }
                                }
                                : nil
                        )
                        .modifier(DockSwitchStagger(
                            index: index,
                            playEnter: isSwitchingDock && !reduceMotion,
                            profileID: store.selectedProfileID,
                            restaggerOnProfileChange: false,
                            reduceMotion: reduceMotion
                        ))
                    }

                    if license.hasAccess {
                        addTile
                            .modifier(DockSwitchStagger(
                                index: displayItems.count,
                                playEnter: isSwitchingDock && !reduceMotion,
                                profileID: store.selectedProfileID,
                                restaggerOnProfileChange: true,
                                reduceMotion: reduceMotion
                            ))
                    }

                    if license.hasAccess || !store.draftOthers.isEmpty {
                        sideDivider
                    }

                    ForEach(Array(store.draftOthers.enumerated()), id: \.element.id) { index, item in
                        OtherTileView(
                            item: item,
                            allowsEditing: license.hasAccess && draggingID == nil,
                            onRemove: { store.removeOther(id: item.id) },
                            onMoveLeft: index > 0
                                ? { store.moveOther(id: item.id, toIndex: index - 1) }
                                : nil,
                            onMoveRight: index < store.draftOthers.count - 1
                                ? { store.moveOther(id: item.id, toIndex: index + 1) }
                                : nil,
                            onChange: { change in store.updateOther(id: item.id, change) }
                        )
                        .modifier(DockSwitchStagger(
                            index: displayItems.count + 1 + index,
                            playEnter: isSwitchingDock && !reduceMotion,
                            profileID: store.selectedProfileID,
                            restaggerOnProfileChange: false,
                            reduceMotion: reduceMotion
                        ))
                    }

                    if license.hasAccess {
                        addOtherTile
                    }
                }
                .padding(.vertical, DockslyStyle.shelfInner)
                .padding(.leading, DockslyStyle.shelfInner)
                .padding(.trailing, overflows ? DockslyStyle.overflowPeek : DockslyStyle.shelfInner)
                .animation(
                    (reduceMotion || isSwitchingDock) ? nil : DockslyStyle.defaultSpring,
                    value: displayItems.map(\.id) + store.draftOthers.map(\.id)
                )
                .overlay(alignment: .topLeading) {
                    floatingTile
                        .transaction { $0.disablesAnimations = true }
                }
                .coordinateSpace(name: DockslyStyle.dockStripSpace)
            }
            .scrollDisabled(draggingID != nil)
            .overlay(alignment: .trailing) {
                if overflows {
                    LinearGradient(
                        colors: [
                            DockslyStyle.shelfFill(colorScheme).opacity(0),
                            DockslyStyle.shelfFill(colorScheme)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: DockslyStyle.overflowPeek)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(height: DockslyStyle.tileRowHeight + (DockslyStyle.shelfInner * 2))
    }

    private var addTile: some View {
        Button(action: onAddApplication) {
            ZStack {
                RoundedRectangle(cornerRadius: DockslyStyle.addTileCorner, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(focusShape: .rounded(DockslyStyle.addTileCorner)))
        .help("Add Application")
        .accessibilityLabel("Add Application")
    }

    /// The thin line between apps and the right side, like the real Dock.
    private var sideDivider: some View {
        Capsule()
            .fill(Color.primary.opacity(0.22))
            .frame(width: 1, height: 44)
            .frame(width: sideDividerWidth, height: 60)
            .accessibilityHidden(true)
    }

    private var addOtherTile: some View {
        Menu {
            Button("Add Folder…") { Self.addFolder(to: store) }
            Button("Add File…") { Self.addFile(to: store) }
            Button("Add Link…") { store.wantsAddLink = true }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: DockslyStyle.addTileCorner, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, height: 52)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 52, height: 52)
        .help("Add Folder, File, or Link")
        .accessibilityLabel("Add Folder, File, or Link")
    }

    static func addFolder(to store: DockStore) {
        let panel = NSOpenPanel()
        panel.title = "Add a folder to this dock"
        panel.prompt = "Add Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls { store.addFolder(path: url.path) }
        }
    }

    static func addFile(to store: DockStore) {
        let panel = NSOpenPanel()
        panel.title = "Add a file to this dock"
        panel.prompt = "Add File"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls { store.addFile(path: url.path) }
        }
    }

    @ViewBuilder
    private var floatingTile: some View {
        if let draggingID, let item = displayItems.first(where: { $0.id == draggingID }) {
            DockTileView(
                item: item,
                isDragging: true,
                isReordering: true,
                onRemove: {}
            )
            .offset(
                x: dragStartX + dragTranslation,
                y: DockslyStyle.shelfInner
            )
            .allowsHitTesting(false)
        }
    }

    private func handleDrag(_ item: DockItem, _ value: DragGesture.Value) {
        if draggingID != item.id {
            draggingID = item.id
            dragItems = store.draftItems
            dragStartX = originX(of: item.id, in: store.draftItems)
            NSCursor.closedHand.set()
        }
        dragTranslation = value.translation.width

        guard var items = dragItems,
              let from = items.firstIndex(where: { $0.id == item.id }) else { return }
        let target = indexAtCenter(
            dragStartX + dragTranslation + tileWidth(item) / 2,
            in: items
        )
        guard target != from else { return }
        let moving = items.remove(at: from)
        items.insert(moving, at: target)
        dragItems = items
    }

    private func endDrag() {
        if let dragItems {
            store.replaceDraftItems(dragItems)
        }
        NSCursor.arrow.set()
        resetDrag()
    }

    private func originX(of id: UUID, in items: [DockItem]) -> CGFloat {
        var x = DockslyStyle.shelfInner
        for item in items {
            if item.id == id { return x }
            x += tileWidth(item) + itemSpacing
        }
        return x
    }

    private func indexAtCenter(_ pointX: CGFloat, in items: [DockItem]) -> Int {
        var x = DockslyStyle.shelfInner
        var result = 0
        for (index, item) in items.enumerated() {
            if pointX >= x + tileWidth(item) / 2 {
                result = index
            }
            x += tileWidth(item) + itemSpacing
        }
        return result
    }

    private func resetDrag() {
        draggingID = nil
        dragTranslation = 0
        dragStartX = 0
        dragItems = nil
    }

    private func tileWidth(_ item: DockItem) -> CGFloat {
        item.kind == .spacer ? DockslyStyle.spacerWidth : DockslyStyle.tileWidth
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
        let delay = min(Double(index) * DockslyStyle.staggerStep, DockslyStyle.staggerCap)
        withAnimation(DockslyStyle.defaultSpring.delay(delay)) {
            visible = true
        }
    }
}
