import Foundation

/// One entry point for switches that come from outside the editor:
/// hotkeys, the Shortcuts app, and Focus filters.
@MainActor
enum DockSwitcher {
    enum Outcome: Equatable {
        /// Docksly wrote the dock to the real Dock.
        case applied
        /// The dock was already on the Dock. Docksly did not restart the Dock.
        case alreadyOnDock
        /// The dock does not exist (for example, it was deleted).
        case missing
        /// The trial ended and no license is active.
        case locked
        /// Docksly could not write the Dock.
        case failed(String)
    }

    @discardableResult
    static func switchTo(profileID: UUID, store: DockStore? = nil) -> Outcome {
        let store = store ?? .shared
        guard LicenseStore.shared.hasAccess else { return .locked }
        guard let profile = store.library.profile(id: profileID) else { return .missing }
        store.saveDraftIfDirty()
        if store.isProfileOnDock(profileID) {
            SwitchHUD.show(profile)
            return .alreadyOnDock
        }
        store.apply(profileID: profileID)
        if store.library.activeProfileID == profileID, store.lastError == nil {
            SwitchHUD.show(profile)
            return .applied
        }
        return .failed(store.lastError ?? "Docksly could not apply this dock.")
    }

    /// Cycles to the dock after the active one, in list order.
    @discardableResult
    static func switchToNext(store: DockStore? = nil) -> Outcome {
        let store = store ?? .shared
        guard let next = store.library.profile(after: store.library.activeProfileID) else {
            return .missing
        }
        return switchTo(profileID: next.id, store: store)
    }

    // MARK: - Focus

    /// A Focus with a Docksly filter turned on. Remembers the dock to restore later.
    @discardableResult
    static func focusDidSelect(profileID: UUID, store: DockStore? = nil) -> Outcome {
        let store = store ?? .shared
        let restore = FocusRestorePlan.restoreTarget(
            current: store.library.focusRestoreProfileID,
            active: store.library.activeProfileID,
            focusDock: profileID
        )
        store.setFocusRestoreProfileID(restore)
        return switchTo(profileID: profileID, store: store)
    }

    /// The Focus turned off. Goes back to the dock that was active before it.
    @discardableResult
    static func focusDidEnd(store: DockStore? = nil) -> Outcome {
        let store = store ?? .shared
        guard let restore = store.library.focusRestoreProfileID else { return .missing }
        store.setFocusRestoreProfileID(nil)
        guard store.library.profile(id: restore) != nil else { return .missing }
        return switchTo(profileID: restore, store: store)
    }
}

/// Pure rule for which dock a Focus restores. Kept apart for tests.
enum FocusRestorePlan {
    /// - `current`: a restore target already saved by an earlier Focus, if any.
    /// - `active`: the dock on the Dock now.
    /// - `focusDock`: the dock the Focus asks for.
    ///
    /// When one Focus replaces another, keep the first saved target, so the
    /// end of the last Focus goes back to the dock from before any Focus.
    static func restoreTarget(current: UUID?, active: UUID?, focusDock: UUID) -> UUID? {
        if let current { return current }
        guard let active, active != focusDock else { return nil }
        return active
    }
}
