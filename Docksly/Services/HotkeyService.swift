import AppKit
import Combine
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Cycles to the next dock. No default key.
    static let nextDock = Self("nextDock")

    /// One global shortcut per dock. The raw value must stay stable, so it uses the dock ID.
    static func dock(_ id: UUID) -> Self {
        Self("dock-\(id.uuidString)")
    }
}

/// Registers the global hotkeys and keeps them in step with the list of docks.
@MainActor
enum HotkeyService {
    private static var registeredIDs: Set<UUID> = []
    private static var cancellable: AnyCancellable?

    static func start(store: DockStore? = nil) {
        let store = store ?? .shared
        guard cancellable == nil else { return }
        KeyboardShortcuts.onKeyUp(for: .nextDock) {
            beepIfLocked(DockSwitcher.switchToNext())
        }
        sync(with: store.library.profiles)
        cancellable = store.$library
            .map { $0.profiles.map(\.id) }
            .removeDuplicates()
            .sink { _ in
                // `$library` publishes before the value changes. Read the new value on the next pass.
                DispatchQueue.main.async {
                    sync(with: store.library.profiles)
                }
            }
    }

    /// Adds handlers for new docks. Removes handlers and stored keys for deleted docks.
    private static func sync(with profiles: [DockProfile]) {
        let ids = Set(profiles.map(\.id))
        for removed in registeredIDs.subtracting(ids) {
            let name = KeyboardShortcuts.Name.dock(removed)
            KeyboardShortcuts.removeHandler(for: name)
            KeyboardShortcuts.reset(name)
        }
        for added in ids.subtracting(registeredIDs) {
            KeyboardShortcuts.onKeyUp(for: .dock(added)) {
                beepIfLocked(DockSwitcher.switchTo(profileID: added))
            }
        }
        registeredIDs = ids
    }

    /// A hotkey has no window to show an error in. A beep tells the user that nothing happened.
    private static func beepIfLocked(_ outcome: DockSwitcher.Outcome) {
        if outcome == .locked { NSSound.beep() }
    }
}
