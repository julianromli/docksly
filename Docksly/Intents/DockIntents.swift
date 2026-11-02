import AppIntents
import Foundation

/// A saved dock, as the Shortcuts app and Focus settings see it.
struct DockEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dock")
    static var defaultQuery = DockEntityQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ profile: DockProfile) {
        self.init(id: profile.id, name: profile.name)
    }
}

struct DockEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [DockEntity] {
        await MainActor.run {
            let profiles = DockStore.shared.library.profiles
            return identifiers.compactMap { id in
                profiles.first { $0.id == id }.map(DockEntity.init)
            }
        }
    }

    func suggestedEntities() async throws -> [DockEntity] {
        await MainActor.run {
            DockStore.shared.library.profiles.map(DockEntity.init)
        }
    }
}

/// Errors that the Shortcuts app shows to the user.
enum DockIntentError: Error, CustomLocalizedStringResourceConvertible {
    case locked
    case missing
    case failed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .locked:
            return "Your Docksly trial has ended. Enter a license key in Docksly Settings."
        case .missing:
            return "Docksly cannot find this dock. It may have been deleted."
        case .failed(let message):
            return "Docksly could not apply this dock. \(message)"
        }
    }
}

struct UseDockIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Dock"
    static var description = IntentDescription("Puts a saved Docksly dock on the macOS Dock.")
    static var openAppWhenRun = false

    @Parameter(title: "Dock")
    var dock: DockEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Use \(\.$dock)")
    }

    func perform() async throws -> some IntentResult {
        let outcome = await MainActor.run {
            DockSwitcher.switchTo(profileID: dock.id)
        }
        switch outcome {
        case .applied, .alreadyOnDock:
            return .result()
        case .locked:
            throw DockIntentError.locked
        case .missing:
            throw DockIntentError.missing
        case .failed(let message):
            throw DockIntentError.failed(message)
        }
    }
}

struct GetCurrentDockIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Current Dock"
    static var description = IntentDescription(
        "Returns the name of the Docksly dock that is on the macOS Dock now. Returns an empty text if no saved dock matches the Dock."
    )
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let name = await MainActor.run { () -> String in
            let store = DockStore.shared
            guard let id = store.library.activeProfileID,
                  store.isProfileOnDock(id),
                  let profile = store.library.profile(id: id) else { return "" }
            return profile.name
        }
        return .result(value: name)
    }
}

/// Focus filter: Settings → Focus → (a Focus) → Add Filter → Docksly.
struct DockFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set Dock"
    static var description: IntentDescription? = IntentDescription(
        "Uses a dock while this Focus is on. When the Focus turns off, Docksly goes back to the dock you had before."
    )

    @Parameter(title: "Dock")
    var dock: DockEntity?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(dock?.name ?? "No dock")")
    }

    func perform() async throws -> some IntentResult {
        // The system calls this with the chosen dock when the Focus turns on,
        // and with default values (no dock) when it turns off.
        let selected = dock?.id
        await MainActor.run {
            if let selected {
                DockSwitcher.focusDidSelect(profileID: selected)
            } else {
                DockSwitcher.focusDidEnd()
            }
        }
        return .result()
    }
}
