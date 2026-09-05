import SwiftUI

struct DockslyCommands: Commands {
    @ObservedObject var store: DockStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Dock") {
                store.wantsNewDockName = true
                NotificationCenter.default.post(name: .dockslyOpenEditor, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Save Changes") {
                store.saveDraft(applyIfActive: true)
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!store.isDirty)
        }

        CommandMenu("Dock") {
            Button("Add Application…") {
                store.wantsAddApp = true
                NotificationCenter.default.post(name: .dockslyOpenEditor, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button("Add Spacer") {
                store.addSpacer()
            }

            Button("Use This Dock") {
                store.applySelected(saveFirst: true)
            }
            .disabled(store.isSelectedCurrent || store.isApplying || (store.isSelectedActive && store.isDirty))
        }
    }
}
