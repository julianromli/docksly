import XCTest
@testable import Docksly

final class CleanUpSelectionTests: XCTestCase {
    private func app(_ id: String, _ name: String) -> CleanUpApp {
        CleanUpApp(bundleIdentifier: id, name: name, path: nil)
    }

    func testRowsDefaultToCheckedAndSessionUnchecksDoNotPersist() {
        var selection = CleanUpSelection()
        selection.replaceLeftovers([app("com.a", "A"), app("com.b", "B")])
        XCTAssertEqual(selection.selected.map(\.bundleIdentifier), ["com.a", "com.b"])

        selection.toggle("com.a")
        XCTAssertEqual(selection.selected.map(\.bundleIdentifier), ["com.b"])
        XCTAssertFalse(selection.isChecked("com.a"))

        selection.replaceLeftovers([app("com.a", "A"), app("com.b", "B")])
        XCTAssertEqual(selection.uncheckedIDs, ["com.a"], "Unchecks last only for this run, until leftover refresh drops the app.")

        selection.replaceLeftovers([app("com.b", "B")])
        XCTAssertEqual(selection.uncheckedIDs, [])
        XCTAssertEqual(selection.selected.map(\.bundleIdentifier), ["com.b"])
    }

    func testAlwaysKeepRemovesTheAppFromTheQuitSetAndMarksKeeping() {
        var selection = CleanUpSelection()
        let figma = app("com.figma", "Figma")
        selection.replaceLeftovers([figma, app("com.slack", "Slack")])
        selection.keep(figma)
        XCTAssertTrue(selection.isKeeping("com.figma"))
        XCTAssertFalse(selection.isChecked("com.figma"))
        XCTAssertEqual(selection.selected.map(\.bundleIdentifier), ["com.slack"])
        XCTAssertEqual(selection.rows.map(\.bundleIdentifier), ["com.figma", "com.slack"])

        selection.replaceLeftovers([app("com.slack", "Slack")])
        XCTAssertTrue(selection.isKeeping("com.figma"), "The Keeping row stays until the review ends.")
        XCTAssertEqual(selection.rows.map(\.bundleIdentifier), ["com.slack", "com.figma"])
    }

    func testKeepingRowsCannotBeToggledBackIntoTheQuitSet() {
        var selection = CleanUpSelection()
        let figma = app("com.figma", "Figma")
        selection.replaceLeftovers([figma])
        selection.keep(figma)
        selection.toggle("com.figma")
        XCTAssertTrue(selection.isKeeping("com.figma"))
        XCTAssertTrue(selection.selected.isEmpty)
    }

    func testUnkeepPutsTheAppBackIntoTheQuitSet() {
        var selection = CleanUpSelection()
        let figma = app("com.figma", "Figma")
        selection.replaceLeftovers([figma, app("com.slack", "Slack")])
        selection.keep(figma)
        selection.replaceLeftovers([app("com.slack", "Slack")])

        selection.unkeep("com.figma")
        selection.replaceLeftovers([figma, app("com.slack", "Slack")])
        XCTAssertFalse(selection.isKeeping("com.figma"))
        XCTAssertTrue(selection.isChecked("com.figma"))
        XCTAssertEqual(selection.selected.map(\.bundleIdentifier), ["com.figma", "com.slack"])
    }

    func testAnAppThatLeavesTheLeftoverListDropsItsUncheck() {
        var selection = CleanUpSelection()
        selection.replaceLeftovers([app("com.a", "A"), app("com.b", "B")])
        selection.toggle("com.a")
        selection.replaceLeftovers([app("com.b", "B")])
        XCTAssertFalse(selection.uncheckedIDs.contains("com.a"))
    }

    func testCopyGrammar() {
        XCTAssertEqual(CleanUpCopy.countLabel(0), "None")
        XCTAssertEqual(CleanUpCopy.countLabel(1), "1 app")
        XCTAssertEqual(CleanUpCopy.countLabel(6), "6 apps")
        XCTAssertEqual(CleanUpCopy.leftoverHeadline(count: 1, dockName: "Work"), "1 app not in Work")
        XCTAssertEqual(CleanUpCopy.leftoverHeadline(count: 6, dockName: "Work"), "6 apps not in Work")
        XCTAssertEqual(CleanUpCopy.holdToQuitTitle(4), "Hold to Quit 4")
        XCTAssertEqual(CleanUpCopy.quittingTitle(4), "Quitting 4…")
        XCTAssertEqual(CleanUpCopy.asking(1), "Asking 1 app to quit…")
        XCTAssertEqual(CleanUpCopy.asking(4), "Asking 4 apps to quit…")
        XCTAssertEqual(CleanUpCopy.askingApp("Slack"), "Asking Slack to quit…")
        XCTAssertEqual(CleanUpCopy.hoverHint("Slack"), "Hold to quit Slack")
        XCTAssertEqual(CleanUpCopy.holdingHint("Slack"), "Keep holding to quit Slack")
        XCTAssertEqual(CleanUpCopy.holdingAllHint(3), "Keep holding to quit 3 apps")
        XCTAssertEqual(CleanUpCopy.armedHint("Slack"), "Press Return again to quit Slack")
        XCTAssertEqual(CleanUpCopy.keptNotice("Spotify"), "Spotify will stay open in every dock.")
        XCTAssertEqual(CleanUpCopy.waitingMessage(names: ["Figma"]), "Figma is waiting for you to save.")
        XCTAssertEqual(CleanUpCopy.waitingMessage(names: ["Figma", "Sketch"]), "2 apps are waiting for you to save.")
    }

    func testAllClearDetailNamesKeptApps() {
        XCTAssertEqual(CleanUpCopy.allClearDetail(dockName: "Work", kept: []), "Only Work apps are running.")
        XCTAssertEqual(
            CleanUpCopy.allClearDetail(dockName: "Work", kept: ["Notion"]),
            "Only Work apps are running. Notion stays open."
        )
        XCTAssertEqual(
            CleanUpCopy.allClearDetail(dockName: "Work", kept: ["Notion", "Spotify"]),
            "Only Work apps are running. Notion and Spotify stay open."
        )
        XCTAssertEqual(
            CleanUpCopy.allClearDetail(dockName: "Work", kept: ["A", "B", "C"]),
            "Only Work apps are running. 3 kept apps stay open."
        )
    }

    func testWaveGapsShrinkAndStayUnder100ms() {
        let gaps = CleanUpStyle.reviewWaveGaps
        XCTAssertEqual(CleanUpStyle.waveDelay(index: 0, gaps: gaps), 0)
        XCTAssertEqual(CleanUpStyle.waveDelay(index: 1, gaps: gaps), 0.04, accuracy: 0.0001)
        XCTAssertEqual(CleanUpStyle.waveDelay(index: 2, gaps: gaps), 0.07, accuracy: 0.0001)
        XCTAssertEqual(CleanUpStyle.waveDelay(index: 3, gaps: gaps), 0.09, accuracy: 0.0001)
        XCTAssertEqual(CleanUpStyle.waveDelay(index: 2, gaps: CleanUpStyle.stripWaveGaps), 0.09, accuracy: 0.0001)
    }

    func testListHeightCapsAtEightRows() {
        XCTAssertEqual(CleanUpStyle.listHeight(rowCount: 0), 0)
        XCTAssertEqual(CleanUpStyle.listHeight(rowCount: 3), 96)
        XCTAssertEqual(CleanUpStyle.listHeight(rowCount: 8), 256)
        XCTAssertEqual(CleanUpStyle.listHeight(rowCount: 30), 256)
    }

    func testQuitPlanStillDecidesLeftovers() {
        let ids = QuitPlan.bundleIdentifiersToQuit(
            running: [
                QuitPlan.RunningApp(bundleIdentifier: "com.apple.finder", isRegularApp: true),
                QuitPlan.RunningApp(bundleIdentifier: "app.docksly.Docksly", isRegularApp: true),
                QuitPlan.RunningApp(bundleIdentifier: "com.keep", isRegularApp: true),
                QuitPlan.RunningApp(bundleIdentifier: "com.docked", isRegularApp: true),
                QuitPlan.RunningApp(bundleIdentifier: "com.leftover", isRegularApp: true),
                QuitPlan.RunningApp(bundleIdentifier: "com.agent", isRegularApp: false)
            ],
            dockApps: ["com.docked"],
            keepOpen: ["com.keep"],
            ownBundleIdentifier: "app.docksly.Docksly"
        )
        XCTAssertEqual(ids, ["com.leftover"])
    }

    func testProtectedDockAppsOfferNothingWhenTheProfileAndLiveDockAreUnreadable() {
        XCTAssertNil(CleanUpController.protectedBundleIDs(profileBundleIDs: nil, livePinned: nil))
    }

    func testProtectedDockAppsUseALiveEmptyDockWhenThereIsNoProfile() {
        XCTAssertEqual(CleanUpController.protectedBundleIDs(profileBundleIDs: nil, livePinned: []), [])
    }

    func testProtectedDockAppsUnionTheProfileAndLiveDock() {
        let ids = CleanUpController.protectedBundleIDs(
            profileBundleIDs: ["com.profile"],
            livePinned: ["com.live"]
        )
        XCTAssertEqual(ids, ["com.profile", "com.live"])
    }

    func testProtectedDockAppsKeepTheProfileWhenTheLiveDockIsUnreadable() {
        let ids = CleanUpController.protectedBundleIDs(
            profileBundleIDs: ["com.profile"],
            livePinned: nil
        )
        XCTAssertEqual(ids, ["com.profile"])
    }
}
