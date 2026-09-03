import Foundation

/// A named Dock layout the user can save and apply.
struct DockProfile: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var color: ProfileColor
    var items: [DockItem]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        color: ProfileColor = .default,
        items: [DockItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var itemCount: Int { items.count }
}
