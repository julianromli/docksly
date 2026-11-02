import AppKit

/// Asks for a name, then saves what the real Dock shows now as a new dock.
/// An `NSAlert` works from the menu bar too, when no Docksly window is open.
@MainActor
enum SaveLiveDockPrompt {
    static func run(store: DockStore? = nil) {
        let store = store ?? .shared
        guard LicenseStore.shared.hasAccess else {
            presentMessage("Docksly is locked", LicenseStore.lockedMessage)
            return
        }
        AppWindowPresentation.activate()

        let alert = NSAlert()
        alert.messageText = "Save Current Dock as New Dock"
        alert.informativeText = "Docksly saves the apps and spacers that are on your Dock now."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Name"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save Dock")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.createDockFromLiveDock(named: name) == nil {
            presentMessage("Docksly could not save the Dock", store.lastError ?? "Try again.")
        }
    }

    private static func presentMessage(_ title: String, _ message: String) {
        AppWindowPresentation.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
