import Foundation

/// A named Dock layout the user can save and apply.
struct DockProfile: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var color: ProfileColor
    var items: [DockItem]
    /// Folders, files, and links on the right side. Nil only in files from before 1.2.
    var otherItems: [DockOtherItem]?
    /// Dock settings for this dock. Nil or `isEnabled == false` means Docksly leaves them alone.
    var appearance: DockAppearance?
    /// 1.3: ask apps that are not in this dock to quit when it is used. Off by default.
    var quitOthersOnSwitch: Bool?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        color: ProfileColor = .default,
        items: [DockItem] = [],
        otherItems: [DockOtherItem]? = [],
        appearance: DockAppearance? = nil,
        quitOthersOnSwitch: Bool? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.items = items
        self.otherItems = otherItems
        self.appearance = appearance
        self.quitOthersOnSwitch = quitOthersOnSwitch
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var itemCount: Int { items.count + (otherItems?.count ?? 0) }

    var layoutSignature: String {
        DockLayout.signature(apps: items, others: otherItems ?? [])
    }
}
