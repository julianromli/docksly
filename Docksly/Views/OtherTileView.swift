import AppKit
import SwiftUI

/// A folder, file, or link tile on the right side of the editor strip.
struct OtherTileView: View {
    let item: DockOtherItem
    var allowsEditing: Bool
    var onRemove: () -> Void
    var onMoveLeft: (() -> Void)?
    var onMoveRight: (() -> Void)?
    var onChange: ((inout DockOtherItem) -> Void) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var missing: Bool {
        guard item.kind != .link, let path = item.path else { return false }
        return !FileManager.default.fileExists(atPath: path)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            icon
                .frame(width: DockslyStyle.iconSize, height: DockslyStyle.iconSize)
                .opacity(missing ? 0.55 : 1)
            if missing {
                Image(systemName: "exclamationmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 12))
                    .offset(x: 4, y: 4)
                    .accessibilityLabel("Item is missing")
            }
        }
        .frame(width: DockslyStyle.tileWidth, height: 60)
        .scaleEffect(isHovering && !reduceMotion ? DockslyStyle.hoverScale : 1)
        .animation(reduceMotion ? nil : DockslyStyle.defaultSpring, value: isHovering)
        .onHover { isHovering = $0 }
        .help(helpText)
        .contextMenu {
            if allowsEditing {
                menuContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kindName), \(item.title)")
        .accessibilityAction(named: "Remove") {
            if allowsEditing { onRemove() }
        }
    }

    private var kindName: String {
        switch item.kind {
        case .folder: return "Folder"
        case .file: return "File"
        case .link: return "Link"
        }
    }

    private var helpText: String {
        let detail = item.kind == .link ? (item.url ?? "") : (item.path ?? "")
        if missing {
            return "\(item.title) — missing on this Mac. Right-click to remove."
        }
        return "\(item.title)\n\(detail)"
    }

    @ViewBuilder
    private var icon: some View {
        switch item.kind {
        case .folder, .file:
            Image(nsImage: Self.fileIcon(item.path, isFolder: item.kind == .folder))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        case .link:
            // The real Dock shows a plain globe for a web link. No network call.
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.accentColor.gradient)
                Image(systemName: "globe")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(3)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if item.kind == .folder {
            Picker("Display as", selection: binding(\.display, .folder)) {
                ForEach(DockOtherItem.FolderDisplay.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Sort by", selection: binding(\.sort, .dateModified)) {
                ForEach(DockOtherItem.FolderSort.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("View content as", selection: binding(\.view, .automatic)) {
                ForEach(DockOtherItem.FolderView.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Divider()
        }
        if item.kind != .link, let path = item.path {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
            Divider()
        }
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

    /// A picker binding for one folder option. Writes go through the store.
    private func binding<Value>(
        _ keyPath: WritableKeyPath<DockOtherItem, Value?>,
        _ fallback: Value
    ) -> Binding<Value> {
        Binding(
            get: { item[keyPath: keyPath] ?? fallback },
            set: { newValue in onChange { $0[keyPath: keyPath] = newValue } }
        )
    }

    private static func fileIcon(_ path: String?, isFolder: Bool) -> NSImage {
        if let path, FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSWorkspace.shared.icon(for: isFolder ? .folder : .data)
    }
}
