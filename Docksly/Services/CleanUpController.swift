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

    mutating func unkeep(_ id: String) {
        keeping.removeAll { $0.bundleIdentifier == id }
    }

    mutating func replaceLeftovers(_ apps: [CleanUpApp]) {
        leftover = apps
        let leftoverIDs = Set(apps.map(\.bundleIdentifier))
        uncheckedIDs = uncheckedIDs.intersection(leftoverIDs)
    }
}

/// Where one app is in its quit. An app with no state is at rest.
enum CleanUpQuitState: Equatable {
    /// Queued in a Quit all wave. It starts in less than 100 ms.
    case next
    /// `terminate()` was sent. The app has not answered yet.
    case quitting
    /// The app is still running after the wait. It usually has unsaved work.
    case waiting
}

/// One nudge request. The token changes each time, so the same app can nudge again.
struct CleanUpNudge: Equatable {
    var id: String
    var token: Int
}

/// Copy for the menu row, review, strip, and All clear.
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

    static func holdToQuitTitle(_ count: Int) -> String {
        "Hold to Quit \(count)"
    }

    static func quittingTitle(_ count: Int) -> String {
        "Quitting \(count)…"
    }

    static func asking(_ count: Int) -> String {
        count == 1 ? "Asking 1 app to quit…" : "Asking \(count) apps to quit…"
    }

    static func askingApp(_ name: String) -> String {
        "Asking \(name) to quit…"
    }

    static func hoverHint(_ name: String) -> String {
        "Hold to quit \(name)"
    }

    static func holdingHint(_ name: String) -> String {
        "Keep holding to quit \(name)"
    }

    static func holdingAllHint(_ count: Int) -> String {
        count == 1 ? "Keep holding to quit 1 app" : "Keep holding to quit \(count) apps"
    }

    static func armedHint(_ name: String) -> String {
        "Press Return again to quit \(name)"
    }

    static func keptNotice(_ name: String) -> String {
        "\(name) will stay open in every dock."
    }

    static func waitingMessage(names: [String]) -> String {
        if names.count == 1 {
            return "\(names[0]) is waiting for you to save."
        }
        return "\(names.count) apps are waiting for you to save."
    }

    static func allClearDetail(dockName: String, kept: [String]) -> String {
        let base = "Only \(dockName) apps are running."
        switch kept.count {
        case 0:
            return base
        case 1:
            return "\(base) \(kept[0]) stays open."
        case 2:
            return "\(base) \(kept[0]) and \(kept[1]) stay open."
        default:
            return "\(base) \(kept.count) kept apps stay open."
        }
    }

    static let allClear = "All clear"
    static let reviewFootnote = "Docksly will ask these apps to quit. It never force quits."
}

enum CleanUpPhase: Equatable {
    case idle
    case review
    /// Nothing is left to quit. The review shows All clear until Done.
    case done
}

enum CleanUpStyle {
    static let popoverWidth: CGFloat = 280
    static let menuRowHeight: CGFloat = 28
    static let reviewRowHeight: CGFloat = 32
    static let listMaxVisibleRows = 8
    static let appIconSize: CGFloat = 20
    static let appIconCorner: CGFloat = 5
    static let checkboxSize: CGFloat = 16
    static let checkboxCorner: CGFloat = 4
    static let pillHeight: CGFloat = 22
    static let footerButtonHeight: CGFloat = 28
    static let footerButtonCorner: CGFloat = 6
    static let stripHeight: CGFloat = 48
    static let stripIconSize: CGFloat = 24
    static let stripIconGap: CGFloat = 10
    static let stripHeadlineWidth: CGFloat = 270
    static let stripMaxIcons = 8
    static let heightAnimation = Animation.easeOut(duration: 0.2)

    // Hold timing. The time is honest, so the fill is linear.
    static let rowHold: Double = 0.6
    static let allHold: Double = 0.9
    static let holdDrain = Animation.easeOut(duration: 0.15)
    static let holdMaxDistance: CGFloat = 6

    // Wave gaps shrink so the whole wave stays under 100 ms.
    static let reviewWaveGaps: [Double] = [0.04, 0.03, 0.02]
    static let stripWaveGaps: [Double] = [0.05, 0.04]

    static let quitWaitTimeout: TimeInterval = 3
    static let quitPollInterval: TimeInterval = 0.2
    static let spinnerDelay: Double = 0.15
    static let armTimeout: TimeInterval = 3
    static let keptNoticeDuration: TimeInterval = 5
    static let allClearFoldDelay: TimeInterval = 1.6

    static let rowReflow = Animation.spring(response: 0.3, dampingFraction: 1)
    static let stripSlide = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let checkPop = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let nudgeSpring = Animation.spring(response: 0.25, dampingFraction: 0.35)
    static let fade150 = Animation.easeOut(duration: 0.15)
    static let fade200 = Animation.easeOut(duration: 0.2)
    static let amber = Color(hex: "FF9F0A")

    /// Delay before the item at `index` starts in a wave.
    static func waveDelay(index: Int, gaps: [Double]) -> Double {
        guard index > 0, let last = gaps.last else { return 0 }
        var total = 0.0
        for step in 0..<index {
            total += step < gaps.count ? gaps[step] : last
        }
        return total
    }

    static func listHeight(rowCount: Int) -> CGFloat {
        let visible = min(max(rowCount, 0), listMaxVisibleRows)
        return CGFloat(visible) * reviewRowHeight
    }
}

/// Haptics only fire on Force Touch trackpads. Other Macs ignore them.
enum CleanUpHaptics {
    static func press() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func complete() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    static func attention() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

/// Shared Clean Up session for the menu bar popover and the editor window.
@MainActor
final class CleanUpController: ObservableObject {
    static let shared = CleanUpController()

    @Published private(set) var phase: CleanUpPhase = .idle
    @Published private(set) var selection = CleanUpSelection()
    @Published private(set) var currentDockName = ""
    @Published private(set) var quitStates: [String: CleanUpQuitState] = [:]
    /// Apps that are still running after the wait, oldest first.
    @Published private(set) var waitingOrder: [String] = []
    /// Bumps when an app starts waiting, so its row or icon nudges once.
    @Published private(set) var nudge: CleanUpNudge?
    /// Set right after Always Keep from the strip. Undo stays for 5 s.
    @Published private(set) var keptNotice: CleanUpApp?
    /// The strip shows All clear, then folds after 1.6 s.
    @Published private(set) var stripAllClear = false
    /// The row or icon that Return armed. A second Return within 3 s quits it.
    @Published private(set) var armedID: String?
    /// True while a Quit all wave is still in flight.
    @Published private(set) var isQuittingAll = false
    @Published var focusedIndex = 0

    private var storeCancellable: AnyCancellable?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var quitTasks: [String: Task<Void, Never>] = [:]
    private var waveTasks: [Task<Void, Never>] = []
    private var keptTask: Task<Void, Never>?
    private var foldTask: Task<Void, Never>?
    private var armTask: Task<Void, Never>?
    private var nudgeCounter = 0
    /// The strip quit or kept something since it last showed its count.
    private var stripActed = false

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
                self?.refreshAnimated()
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

    // MARK: - Reading state

    var leftoverCount: Int { selection.leftover.count }

    var hasLeftovers: Bool { leftoverCount > 0 }

    var selectedCount: Int { selection.selected.count }

    var reviewRows: [CleanUpApp] { selection.rows }

    var canStartReview: Bool {
        leftoverCount > 0 && LicenseStore.shared.hasAccess
    }

    var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func isKeeping(_ id: String) -> Bool {
        selection.isKeeping(id)
    }

    func isChecked(_ id: String) -> Bool {
        selection.isChecked(id)
    }

    func quitState(_ id: String) -> CleanUpQuitState? {
        quitStates[id]
    }

    /// Apps that were asked to quit and have not answered yet.
    var quittingApps: [CleanUpApp] {
        selection.leftover.filter { quitStates[$0.id] == .quitting || quitStates[$0.id] == .next }
    }

    var waitingApps: [CleanUpApp] {
        waitingOrder.compactMap { id in selection.leftover.first { $0.id == id } }
    }

    var armedApp: CleanUpApp? {
        guard let armedID else { return nil }
        return reviewRows.first { $0.id == armedID }
    }

    // MARK: - Review

    func toggleChecked(_ id: String) {
        guard phase == .review else { return }
        selection.toggle(id)
    }

    func moveFocus(by delta: Int) {
        let rows = reviewRows
        guard !rows.isEmpty else { return }
        focusedIndex = min(max(focusedIndex + delta, 0), rows.count - 1)
        disarm()
    }

    func toggleFocusedRow() {
        guard phase == .review, reviewRows.indices.contains(focusedIndex) else { return }
        toggleChecked(reviewRows[focusedIndex].bundleIdentifier)
    }

    func beginReview() {
        guard phase == .idle, canStartReview else { return }
        resetSession()
        refresh()
        guard !selection.leftover.isEmpty else { return }
        phase = .review
    }

    func cancelReview() {
        resetSession()
        phase = .idle
        refresh()
    }

    /// Return in the review: Done in All clear, else arm the focused row, then quit it.
    func handleReturn() {
        switch phase {
        case .done:
            cancelReview()
        case .review:
            guard reviewRows.indices.contains(focusedIndex) else { return }
            let app = reviewRows[focusedIndex]
            guard !isKeeping(app.id) else { return }
            pressReturn(on: app)
        case .idle:
            break
        }
    }

    /// Esc disarms first. With nothing armed it closes the review.
    func handleEscape() {
        if armedID != nil {
            disarm()
            return
        }
        switch phase {
        case .review, .done:
            cancelReview()
        case .idle:
            break
        }
    }

    // MARK: - Keyboard arm (Return twice)

    /// First Return arms the app. A second Return within 3 s quits it.
    func pressReturn(on app: CleanUpApp) {
        guard LicenseStore.shared.hasAccess else { return }
        if armedID == app.id {
            disarm()
            quit(app)
            return
        }
        armedID = app.id
        armTask?.cancel()
        armTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(CleanUpStyle.armTimeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.armedID = nil
        }
    }

    func disarm() {
        armTask?.cancel()
        armTask = nil
        armedID = nil
    }

    // MARK: - Quit

    /// Asks one app to quit. A hold or a menu pick already confirmed it.
    func quit(_ app: CleanUpApp, fromStrip: Bool = false) {
        guard LicenseStore.shared.hasAccess else { return }
        guard quitStates[app.id] != .quitting else { return }
        if fromStrip { stripActed = true }
        if armedID == app.id { disarm() }
        setQuitState(.quitting, for: app.id)
        waitingOrder.removeAll { $0 == app.id }
        SwitchActions.askToQuit(bundleIdentifiers: [app.id])
        watch(app.id)
    }

    /// Quit all from the review: the checked apps. From the strip: every app in the strip.
    func quitAll(fromStrip: Bool) {
        guard LicenseStore.shared.hasAccess, !isQuittingAll else { return }
        let apps = fromStrip ? selection.leftover : selection.selected
        let targets = apps.filter { quitStates[$0.id] != .quitting }
        guard !targets.isEmpty else { return }
        if fromStrip { stripActed = true }
        disarm()
        isQuittingAll = true
        let gaps = fromStrip ? CleanUpStyle.stripWaveGaps : CleanUpStyle.reviewWaveGaps
        let delays = reduceMotion
            ? Array(repeating: 0.0, count: targets.count)
            : targets.indices.map { CleanUpStyle.waveDelay(index: $0, gaps: gaps) }
        for (index, app) in targets.enumerated() where delays[index] > 0 {
            setQuitState(.next, for: app.id)
        }
        waveTasks.forEach { $0.cancel() }
        waveTasks = targets.enumerated().map { index, app in
            Task { [weak self] in
                let delay = delays[index]
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
                self?.quit(app, fromStrip: fromStrip)
            }
        }
    }

    func showWaiting(_ app: CleanUpApp) {
        SwitchActions.activate(bundleIdentifier: app.bundleIdentifier)
    }

    private func watch(_ id: String) {
        quitTasks[id]?.cancel()
        quitTasks[id] = Task { [weak self] in
            let deadline = Date().addingTimeInterval(CleanUpStyle.quitWaitTimeout)
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: UInt64(CleanUpStyle.quitPollInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                if !Self.isRunning(id) { break }
            }
            guard !Task.isCancelled else { return }
            self?.finishWatch(id)
        }
    }

    private func finishWatch(_ id: String) {
        quitTasks[id] = nil
        if Self.isRunning(id) {
            setQuitState(.waiting, for: id)
            if !waitingOrder.contains(id) { waitingOrder.append(id) }
            nudgeCounter += 1
            nudge = CleanUpNudge(id: id, token: nudgeCounter)
            CleanUpHaptics.attention()
        } else {
            refreshAnimated()
        }
        updateQuittingAll()
    }

    private func setQuitState(_ state: CleanUpQuitState?, for id: String) {
        let animation: Animation = CleanUpStyle.fade150
        withAnimation(animation) {
            quitStates[id] = state
        }
    }

    private func updateQuittingAll() {
        guard isQuittingAll else { return }
        if quitStates.values.allSatisfy({ $0 == .waiting }) {
            isQuittingAll = false
        }
    }

    private nonisolated static func isRunning(_ id: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: id).contains { !$0.isTerminated }
    }

    // MARK: - Keep

    func alwaysKeep(_ app: CleanUpApp, fromStrip: Bool = false) {
        guard LicenseStore.shared.hasAccess else { return }
        var list = DockStore.shared.library.alwaysKeepOpen ?? []
        let entry = KeepOpenApp(bundleIdentifier: app.bundleIdentifier, name: app.name)
        if !list.contains(where: { $0.bundleIdentifier == entry.bundleIdentifier }) {
            list.append(entry)
            DockStore.shared.setAlwaysKeepOpen(list)
        }
        withAnimation(CleanUpStyle.fade150) {
            if phase == .review {
                selection.keep(app)
            }
            quitStates[app.id] = nil
            waitingOrder.removeAll { $0 == app.id }
        }
        if fromStrip {
            stripActed = true
            showKeptNotice(app)
        }
        refreshAnimated()
    }

    /// Removes the app from Apps to Keep Open. The app goes back to the review as a selected leftover.
    func stopKeeping(_ app: CleanUpApp) {
        guard LicenseStore.shared.hasAccess else { return }
        var list = DockStore.shared.library.alwaysKeepOpen ?? []
        if list.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            list.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
            DockStore.shared.setAlwaysKeepOpen(list)
        }
        withAnimation(CleanUpStyle.fade150) {
            selection.unkeep(app.bundleIdentifier)
        }
        refreshAnimated()
    }

    func toggleKeep(_ app: CleanUpApp) {
        if isKeeping(app.bundleIdentifier) {
            stopKeeping(app)
        } else {
            alwaysKeep(app)
        }
    }

    /// Undo for the strip's "will stay open" notice.
    func undoKeep() {
        guard let app = keptNotice else { return }
        clearKeptNotice()
        stopKeeping(app)
    }

    private func showKeptNotice(_ app: CleanUpApp) {
        keptTask?.cancel()
        withAnimation(CleanUpStyle.fade150) { keptNotice = app }
        keptTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(CleanUpStyle.keptNoticeDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.clearKeptNotice()
        }
    }

    private func clearKeptNotice() {
        keptTask?.cancel()
        keptTask = nil
        withAnimation(CleanUpStyle.fade150) { keptNotice = nil }
    }

    // MARK: - All clear

    /// Done in the strip's All clear, or the fold after 1.6 s.
    func dismissStripAllClear() {
        foldTask?.cancel()
        foldTask = nil
        stripActed = false
        stripAllClear = false
    }

    private func showStripAllClear() {
        stripAllClear = true
        CleanUpHaptics.complete()
        foldTask?.cancel()
        foldTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(CleanUpStyle.allClearFoldDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismissStripAllClear()
        }
    }

    // MARK: - Refresh

    /// Refresh inside the row and icon reflow animations.
    func refreshAnimated() {
        if reduceMotion {
            refresh()
        } else {
            withAnimation(CleanUpStyle.rowReflow) {
                refresh()
            }
        }
    }

    func refresh() {
        let snapshot = Self.liveLeftovers(store: DockStore.shared)
        currentDockName = snapshot.dockName
        selection.replaceLeftovers(snapshot.apps)
        pruneQuitStates()
        if focusedIndex >= reviewRows.count {
            focusedIndex = max(reviewRows.count - 1, 0)
        }
        if let armedID, !reviewRows.contains(where: { $0.id == armedID }) {
            disarm()
        }
        if phase == .review, selection.leftover.isEmpty {
            phase = .done
            CleanUpHaptics.complete()
        }
        if phase == .idle, selection.leftover.isEmpty, stripActed, !stripAllClear {
            stripActed = false
            clearKeptNotice()
            showStripAllClear()
        }
        if !selection.leftover.isEmpty, stripAllClear {
            dismissStripAllClear()
        }
    }

    private func pruneQuitStates() {
        let live = Set(selection.leftover.map(\.id))
        for id in quitStates.keys where !live.contains(id) {
            quitStates[id] = nil
            quitTasks[id]?.cancel()
            quitTasks[id] = nil
        }
        waitingOrder.removeAll { !live.contains($0) }
        updateQuittingAll()
    }

    private func resetSession() {
        quitTasks.values.forEach { $0.cancel() }
        quitTasks = [:]
        waveTasks.forEach { $0.cancel() }
        waveTasks = []
        quitStates = [:]
        waitingOrder = []
        isQuittingAll = false
        focusedIndex = 0
        disarm()
        selection.uncheckedIDs = []
        selection.keeping = []
    }

    /// Bundle IDs treated as already in the dock. `livePinned` is nil when the live Dock
    /// cannot be read. Returns nil when Clean Up must offer nothing (no active profile
    /// and an unreadable Dock).
    nonisolated static func protectedBundleIDs(profileBundleIDs: Set<String>?, livePinned: Set<String>?) -> Set<String>? {
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
}
