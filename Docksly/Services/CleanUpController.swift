import AppKit
import Combine
import Foundation
import SwiftUI

/// One leftover app in a Clean Up review.
struct CleanUpApp: Identifiable, Equatable, Hashable {
    var bundleIdentifier: String
    var name: String
    var path: String?

    var id: String { bundleIdentifier }
}

/// Session-only review state. Unchecks are not persisted. Keeping is stored in the library.
struct CleanUpSelection: Equatable {
    var leftover: [CleanUpApp] = []
    var keeping: [CleanUpApp] = []
    var uncheckedIDs: Set<String> = []

    var rows: [CleanUpApp] {
        var seen = Set<String>()
        var result: [CleanUpApp] = []
        for app in leftover + keeping {
            if seen.insert(app.bundleIdentifier).inserted {
                result.append(app)
            }
        }
        return result
    }

    var selected: [CleanUpApp] {
        leftover.filter { !uncheckedIDs.contains($0.bundleIdentifier) && !isKeeping($0.bundleIdentifier) }
    }

    func isKeeping(_ id: String) -> Bool {
        keeping.contains { $0.bundleIdentifier == id }
    }

    func isChecked(_ id: String) -> Bool {
        !uncheckedIDs.contains(id) && !isKeeping(id)
    }

    mutating func toggle(_ id: String) {
        guard !isKeeping(id), leftover.contains(where: { $0.bundleIdentifier == id }) else { return }
        if uncheckedIDs.contains(id) {
            uncheckedIDs.remove(id)
        } else {
            uncheckedIDs.insert(id)
        }
    }

    mutating func keep(_ app: CleanUpApp) {
        if !keeping.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            keeping.append(app)
        }
        uncheckedIDs.remove(app.bundleIdentifier)
    }

    mutating func replaceLeftovers(_ apps: [CleanUpApp]) {
        leftover = apps
        let leftoverIDs = Set(apps.map(\.bundleIdentifier))
        uncheckedIDs = uncheckedIDs.intersection(leftoverIDs)
    }
}

/// Copy for the menu row, review, progress, and result.
enum CleanUpCopy {
    static func countLabel(_ count: Int) -> String {
        if count <= 0 { return "None" }
        if count == 1 { return "1 app" }
        return "\(count) apps"
    }

    static func leftoverHeadline(count: Int, dockName: String) -> String {
        let noun = count == 1 ? "1 app" : "\(count) apps"
        return "\(noun) not in \(dockName)"
    }

    static func quitTitle(_ count: Int) -> String {
        count == 1 ? "Quit 1 App" : "Quit \(count) Apps"
    }

    static func asking(_ count: Int) -> String {
        count == 1 ? "Asking 1 app to quit…" : "Asking \(count) apps to quit…"
    }

    static func resultTitle(quitCount: Int) -> String {
        if quitCount <= 0 { return "No apps quit" }
        return quitCount == 1 ? "Quit 1 app" : "Quit \(quitCount) apps"
    }

    static func waitingMessage(names: [String]) -> String {
        if names.count == 1 {
            return "\(names[0]) is waiting for you to save."
        }
        return "\(names.count) apps are waiting for you to save."
    }

    static let reviewFootnote = "Docksly will ask these apps to quit. It never force quits."
}

enum CleanUpPhase: Equatable {
    case idle
    case review
    case asking
    case result
}

enum CleanUpStyle {
    static let popoverWidth: CGFloat = 280
    static let menuRowHeight: CGFloat = 28
    static let reviewRowHeight: CGFloat = 32
    static let listMaxVisibleRows = 8
    static let listMaxHeight: CGFloat = 256
    static let appIconSize: CGFloat = 20
    static let appIconCorner: CGFloat = 5
    static let checkboxSize: CGFloat = 16
    static let checkboxCorner: CGFloat = 4
    static let pinHit: CGFloat = 22
    static let footerButtonHeight: CGFloat = 28
    static let footerButtonCorner: CGFloat = 6
    static let stripHeight: CGFloat = 48
    static let stripIconSize: CGFloat = 24
    static let stripMaxIcons = 8
    static let heightAnimation = Animation.easeOut(duration: 0.2)
    static let quitWaitTimeout: TimeInterval = 3
    static let quitPollInterval: TimeInterval = 0.2

    static func listHeight(rowCount: Int) -> CGFloat {
        let visible = min(max(rowCount, 0), listMaxVisibleRows)
        return CGFloat(visible) * reviewRowHeight
    }

    static func editorReviewHeight(rowCount: Int, phase: CleanUpPhase) -> CGFloat {
        let header: CGFloat = 56
        let footer: CGFloat = 40
        let padding: CGFloat = 16
        switch phase {
        case .idle:
            return 0
        case .asking:
            return 36 + padding
        case .result:
            return header + listHeight(rowCount: max(rowCount, 1)) + footer + padding
        case .review:
            return header + listHeight(rowCount: rowCount) + footer + padding
        }
    }
}

/// Shared Clean Up session for the menu bar popover and the editor window.
@MainActor
final class CleanUpController: ObservableObject {
    static let shared = CleanUpController()

    @Published private(set) var phase: CleanUpPhase = .idle
    @Published private(set) var selection = CleanUpSelection()
    @Published private(set) var currentDockName = ""
    @Published private(set) var askingCount = 0
    @Published private(set) var quitCount = 0
    @Published private(set) var waiting: [CleanUpApp] = []
    @Published var focusedIndex = 0

    private var storeCancellable: AnyCancellable?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var quitTask: Task<Void, Never>?
    private var requestedIDs: [String] = []

    private init() {
        refresh()
        storeCancellable = DockStore.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
        let center = NSWorkspace.shared.notificationCenter
        let handler: (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.pruneWaiting()
            }
        }
        workspaceObservers = [
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: handler),
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: handler)
        ]
    }

    deinit {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    var leftoverCount: Int { selection.leftover.count }

    var hasLeftovers: Bool { leftoverCount > 0 }

    var selectedCount: Int { selection.selected.count }

    var reviewRows: [CleanUpApp] { selection.rows }

    var canStartReview: Bool {
        leftoverCount > 0 && LicenseStore.shared.hasAccess
    }

    var showsNothingToClean: Bool {
        phase == .review && selection.leftover.isEmpty && selection.keeping.isEmpty
    }

    func isKeeping(_ id: String) -> Bool {
        selection.isKeeping(id)
    }

    func isChecked(_ id: String) -> Bool {
        selection.isChecked(id)
    }

    func toggleChecked(_ id: String) {
        guard phase == .review else { return }
        selection.toggle(id)
    }

    func moveFocus(by delta: Int) {
        let rows = reviewRows
        guard !rows.isEmpty else { return }
        focusedIndex = min(max(focusedIndex + delta, 0), rows.count - 1)
    }

    func toggleFocusedRow() {
        guard phase == .review, reviewRows.indices.contains(focusedIndex) else { return }
        toggleChecked(reviewRows[focusedIndex].bundleIdentifier)
    }

    func alwaysKeep(_ app: CleanUpApp) {
        guard LicenseStore.shared.hasAccess, phase == .review else { return }
        var list = DockStore.shared.library.alwaysKeepOpen ?? []
        let entry = KeepOpenApp(bundleIdentifier: app.bundleIdentifier, name: app.name)
        if !list.contains(where: { $0.bundleIdentifier == entry.bundleIdentifier }) {
            list.append(entry)
            DockStore.shared.setAlwaysKeepOpen(list)
        }
        selection.keep(app)
        refresh()
    }

    func beginReview() {
        guard phase == .idle, canStartReview else { return }
        quitTask?.cancel()
        quitTask = nil
        requestedIDs = []
        waiting = []
        quitCount = 0
        askingCount = 0
        focusedIndex = 0
        selection.uncheckedIDs = []
        selection.keeping = []
        refresh()
        guard !selection.leftover.isEmpty else { return }
        phase = .review
    }

    func cancelReview() {
        quitTask?.cancel()
        quitTask = nil
        requestedIDs = []
        waiting = []
        quitCount = 0
        askingCount = 0
        focusedIndex = 0
        selection.uncheckedIDs = []
        selection.keeping = []
        phase = .idle
        refresh()
    }

    func performPrimary() {
        switch phase {
        case .review:
            startQuit()
        case .result:
            cancelReview()
        case .idle, .asking:
            break
        }
    }

    func goBack() {
        switch phase {
        case .review, .result:
            cancelReview()
        case .idle, .asking:
            break
        }
    }

    func startQuit() {
        let apps = selection.selected
        guard phase == .review, !apps.isEmpty else { return }
        requestedIDs = apps.map(\.bundleIdentifier)
        askingCount = apps.count
        phase = .asking
        SwitchActions.askToQuit(bundleIdentifiers: requestedIDs)
        quitTask?.cancel()
        let ids = requestedIDs
        quitTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(CleanUpStyle.quitWaitTimeout)
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: UInt64(CleanUpStyle.quitPollInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                let remaining = await MainActor.run { self?.stillRunning(ids: ids) ?? [] }
                if remaining.isEmpty { break }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.finishQuit(requestedIDs: ids)
            }
        }
    }

    func showWaiting(_ app: CleanUpApp) {
        SwitchActions.activate(bundleIdentifier: app.bundleIdentifier)
    }

    func refresh() {
        let snapshot = Self.liveLeftovers(store: DockStore.shared)
        currentDockName = snapshot.dockName
        selection.replaceLeftovers(snapshot.apps)
        if focusedIndex >= reviewRows.count {
            focusedIndex = max(reviewRows.count - 1, 0)
        }
        if phase == .review, selection.leftover.isEmpty, selection.keeping.isEmpty {
            phase = .idle
        }
    }

    /// Bundle IDs treated as already in the dock. `livePinned` is nil when the live Dock
    /// cannot be read. Returns nil when Clean Up must offer nothing (no active profile
    /// and an unreadable Dock).
    static func protectedBundleIDs(profileBundleIDs: Set<String>?, livePinned: Set<String>?) -> Set<String>? {
        if let livePinned {
            return (profileBundleIDs ?? []).union(livePinned)
        }
        guard let profileBundleIDs else { return nil }
        return profileBundleIDs
    }

    /// Builds leftovers with `QuitPlan` against the active dock, live pinned apps, and the global Keep Open list.
    static func liveLeftovers(store: DockStore) -> (dockName: String, apps: [CleanUpApp]) {
        let profile = store.library.profiles.first { $0.id == store.library.activeProfileID }
        let dockName = profile?.name ?? "this dock"
        let runningApplications = NSWorkspace.shared.runningApplications
        let running = runningApplications.map {
            QuitPlan.RunningApp(
                bundleIdentifier: $0.bundleIdentifier,
                isRegularApp: $0.activationPolicy == .regular
            )
        }
        let livePinned: Set<String>?
        if let liveItems = try? DockApplicator.readPinnedItems() {
            livePinned = Set(liveItems.compactMap(\.bundleIdentifier))
        } else {
            livePinned = nil
        }
        let profileIDs = profile.map { Set($0.items.compactMap(\.bundleIdentifier)) }
        guard let dockApps = protectedBundleIDs(profileBundleIDs: profileIDs, livePinned: livePinned) else {
            return (dockName, [])
        }
        let keepOpen = Set((store.library.alwaysKeepOpen ?? []).map(\.bundleIdentifier))
        let ids = QuitPlan.bundleIdentifiersToQuit(
            running: running,
            dockApps: dockApps,
            keepOpen: keepOpen,
            ownBundleIdentifier: Bundle.main.bundleIdentifier ?? "app.docksly.Docksly"
        )
        var seen = Set<String>()
        var apps: [CleanUpApp] = []
        for id in ids where seen.insert(id).inserted {
            let runningApp = runningApplications.first { $0.bundleIdentifier == id }
            apps.append(
                CleanUpApp(
                    bundleIdentifier: id,
                    name: runningApp?.localizedName ?? id,
                    path: runningApp?.bundleURL?.path
                )
            )
        }
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (dockName, apps)
    }

    private func stillRunning(ids: [String]) -> [CleanUpApp] {
        ids.compactMap { id in
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            guard running.contains(where: { !$0.isTerminated }) else { return nil }
            if let known = selection.leftover.first(where: { $0.bundleIdentifier == id })
                ?? reviewRows.first(where: { $0.bundleIdentifier == id })
                ?? waiting.first(where: { $0.bundleIdentifier == id })
            {
                return known
            }
            let app = running.first
            return CleanUpApp(
                bundleIdentifier: id,
                name: app?.localizedName ?? id,
                path: app?.bundleURL?.path
            )
        }
    }

    private func finishQuit(requestedIDs: [String]) {
        refresh()
        let remaining = stillRunning(ids: requestedIDs)
        quitCount = max(requestedIDs.count - remaining.count, 0)
        waiting = remaining
        askingCount = 0
        quitTask = nil
        if remaining.isEmpty {
            selection.uncheckedIDs = []
            selection.keeping = []
            phase = .idle
        } else {
            phase = .result
        }
    }

    private func pruneWaiting() {
        guard phase == .result, !waiting.isEmpty else { return }
        waiting = stillRunning(ids: waiting.map(\.bundleIdentifier))
        quitCount = max(requestedIDs.count - waiting.count, 0)
        if waiting.isEmpty {
            selection.uncheckedIDs = []
            selection.keeping = []
            phase = .idle
        }
    }
}
