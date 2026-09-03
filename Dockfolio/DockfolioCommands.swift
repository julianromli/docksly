import SwiftUI

struct DockfolioCommands: Commands {
    @ObservedObject var store: DockStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Dock") {
                store.createDock()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Save Changes") {
                store.saveDraft(applyIfActive: true)
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!store.isDirty)
        }
    }
}
