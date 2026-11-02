import XCTest
@testable import Docksly

final class DockSwitcherLogicTests: XCTestCase {
    private let main = DockProfile(name: "Main")
    private let work = DockProfile(name: "Work")
    private let play = DockProfile(name: "Play")

    func testNextDockCyclesInListOrder() {
        let library = DockLibrary(profiles: [main, work, play])
        XCTAssertEqual(library.profile(after: main.id)?.id, work.id)
        XCTAssertEqual(library.profile(after: work.id)?.id, play.id)
        XCTAssertEqual(library.profile(after: play.id)?.id, main.id)
    }

    func testNextDockWithNoActiveDockStartsAtFirst() {
        let library = DockLibrary(profiles: [main, work])
        XCTAssertEqual(library.profile(after: nil)?.id, main.id)
        XCTAssertEqual(library.profile(after: UUID())?.id, main.id)
        XCTAssertNil(DockLibrary().profile(after: nil))
    }

    func testFocusRemembersTheDockFromBefore() {
        let target = FocusRestorePlan.restoreTarget(current: nil, active: main.id, focusDock: work.id)
        XCTAssertEqual(target, main.id)
    }

    func testFocusOnTheActiveDockHasNothingToRestore() {
        let target = FocusRestorePlan.restoreTarget(current: nil, active: work.id, focusDock: work.id)
        XCTAssertNil(target)
    }

    func testSecondFocusKeepsTheFirstRestoreTarget() {
        // Main → Work Focus → Play Focus. The end goes back to Main, not Work.
        let target = FocusRestorePlan.restoreTarget(current: main.id, active: work.id, focusDock: play.id)
        XCTAssertEqual(target, main.id)
    }

    func testFocusWithNoActiveDockHasNothingToRestore() {
        XCTAssertNil(FocusRestorePlan.restoreTarget(current: nil, active: nil, focusDock: work.id))
    }
}
