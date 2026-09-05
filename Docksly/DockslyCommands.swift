import SwiftUI

struct DockslyCommands: Commands {
    @ObservedObject var store: DockStore
    @ObservedObject var license: LicenseStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Dock") {
                store.wantsNewDockName = true
                NotificationCenter.default.post(name: .dockslyOpenEditor, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!license.hasAccess)

            Button("Save Changes") {
                store.saveDraft(applyIfActive: true)
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!store.isDirty || !license.hasAccess)
        }

        CommandMenu("Dock") {
            Button("Add Application…") {
                store.wantsAddApp = true
                NotificationCenter.default.post(name: .dockslyOpenEditor, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(!license.hasAccess)

            Button("Add Spacer") {
                store.addSpacer()
            }
            .disabled(!license.hasAccess)

            Button("Use This Dock") {
                store.applySelected(saveFirst: true)
            }
            .disabled(
                !license.hasAccess
                    || store.isSelectedCurrent
                    || store.isApplying
                    || (store.isSelectedActive && store.isDirty)
            )
        }
    }
}
