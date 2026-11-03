import AppKit
import Foundation

/// Applies a dock when the set of connected displays changes, if a rule exists for it.
/// Also applies at a launch at login, using the displays connected then.
@MainActor
enum DisplayWatcher {
    private static var lastKey: String?
    private static var observer: NSObjectProtocol?

    static func start(store: DockStore? = nil) {
        guard observer == nil else { return }
        lastKey = DisplaySetKey.make(DisplayIdentity.current())
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                handleChange(store: store)
            }
        }
    }

    /// Called at a launch at login. Applies the rule for the displays connected now.
    static func applyForCurrentDisplays(store: DockStore? = nil) {
        let store = store ?? .shared
        let key = DisplaySetKey.make(DisplayIdentity.current())
        lastKey = key
        apply(for: key, store: store)
    }

    private static func handleChange(store: DockStore?) {
        let store = store ?? .shared
        let key = DisplaySetKey.make(DisplayIdentity.current())
        // The notification can fire more than once for one change. Act only on a new set.
        guard key != lastKey else { return }
        lastKey = key
        apply(for: key, store: store)
    }

    private static func apply(for key: String, store: DockStore) {
        guard let profileID = DisplayRuleResolver.profileID(for: key, in: store.library.displayRules ?? []) else {
            return
        }
        DockSwitcher.switchTo(profileID: profileID, store: store)
    }
}
