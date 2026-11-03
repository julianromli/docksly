import XCTest
@testable import Docksly

final class AppRulesTests: XCTestCase {
    // MARK: - Display sets

    private let studio = DisplayIdentity(vendor: 1552, model: 40961, serial: 1234, name: "Studio Display")
    private let builtIn = DisplayIdentity(vendor: 1552, model: 40962, serial: 0, name: "Built-in Retina Display")

    func testDisplaySetKeyIgnoresOrder() {
        XCTAssertEqual(DisplaySetKey.make([studio, builtIn]), DisplaySetKey.make([builtIn, studio]))
    }

    func testDisplaySetKeySeparatesDifferentSets() {
        XCTAssertNotEqual(DisplaySetKey.make([studio]), DisplaySetKey.make([studio, builtIn]))
    }

    func testSameModelWithDifferentSerialIsADifferentDisplay() {
        let second = DisplayIdentity(vendor: 1552, model: 40961, serial: 9999, name: "Studio Display")
        XCTAssertNotEqual(DisplaySetKey.make([studio]), DisplaySetKey.make([second]))
    }

    func testReadableNameIsSortedAndJoined() {
        XCTAssertEqual(
            DisplaySetKey.readableName([studio, builtIn]),
            "Built-in Retina Display + Studio Display"
        )
        XCTAssertEqual(DisplaySetKey.readableName([]), "No display")
    }

    // MARK: - Rules

    func testRuleResolvesExactSetOnly() {
        let dock = UUID()
        let rules = [DisplayRule(setKey: DisplaySetKey.make([studio, builtIn]), setName: "Both", profileID: dock)]
        XCTAssertEqual(DisplayRuleResolver.profileID(for: DisplaySetKey.make([builtIn, studio]), in: rules), dock)
        XCTAssertNil(DisplayRuleResolver.profileID(for: DisplaySetKey.make([studio]), in: rules))
        XCTAssertNil(DisplayRuleResolver.profileID(for: DisplaySetKey.make([studio]), in: []))
    }

    func testUpsertReplacesRuleForTheSameSet() {
        let key = DisplaySetKey.make([studio])
        let first = DisplayRule(setKey: key, setName: "Studio Display", profileID: UUID())
        let newDock = UUID()
        let second = DisplayRule(setKey: key, setName: "Studio Display", profileID: newDock)
        let rules = DisplayRuleResolver.upsert(second, into: DisplayRuleResolver.upsert(first, into: []))
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].profileID, newDock)
    }

    func testRemovingADockRemovesItsRules() {
        let work = DockProfile(name: "Work")
        var library = DockLibrary(profiles: [work, DockProfile(name: "Main")])
        library.displayRules = [
            DisplayRule(setKey: "a", setName: "A", profileID: work.id),
            DisplayRule(setKey: "b", setName: "B", profileID: library.profiles[1].id),
        ]
        library.remove(id: work.id)
        XCTAssertEqual(library.displayRules?.map(\.setKey), ["b"])
    }

    // MARK: - Quit plan

    private func running(_ id: String?, regular: Bool = true) -> QuitPlan.RunningApp {
        QuitPlan.RunningApp(bundleIdentifier: id, isRegularApp: regular)
    }

    func testQuitsOnlyRegularAppsNotInTheDock() {
        let ids = QuitPlan.bundleIdentifiersToQuit(
            running: [running("com.a"), running("com.b"), running("com.c")],
            dockApps: ["com.a"],
            keepOpen: [],
            ownBundleIdentifier: "app.docksly.Docksly"
        )
        XCTAssertEqual(ids, ["com.b", "com.c"])
    }

    func testNeverQuitsFinderDocksslyOrKeptApps() {
        let ids = QuitPlan.bundleIdentifiersToQuit(
            running: [running("com.apple.finder"), running("app.docksly.Docksly"), running("com.keep"), running("com.other")],
            dockApps: [],
            keepOpen: ["com.keep"],
            ownBundleIdentifier: "app.docksly.Docksly"
        )
        XCTAssertEqual(ids, ["com.other"])
    }

    func testBackgroundAgentsAndUnknownAppsAreNotQuit() {
        let ids = QuitPlan.bundleIdentifiersToQuit(
            running: [running("com.agent", regular: false), running(nil)],
            dockApps: [],
            keepOpen: [],
            ownBundleIdentifier: "app.docksly.Docksly"
        )
        XCTAssertEqual(ids, [])
    }

    // MARK: - Open targets

    func testOpenTargetAcceptsPathsAndWebAddresses() {
        XCTAssertEqual(OpenTarget.url(from: "/Users/me/Projects")?.isFileURL, true)
        XCTAssertEqual(OpenTarget.url(from: "https://example.com/a")?.absoluteString, "https://example.com/a")
        XCTAssertNil(OpenTarget.url(from: "  "))
        XCTAssertNil(OpenTarget.url(from: "relative/path"))
    }

    // MARK: - Library and dock fields (1.3)

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testLegacyItemDecodesWithNoOpenOption() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"application","bundleIdentifier":"com.apple.Safari","bookmarkPath":"/Applications/Safari.app","displayName":"Safari"}"#
        let item = try decoder.decode(DockItem.self, from: Data(json.utf8))
        XCTAssertNil(item.opensWhenUsed)
        XCTAssertNil(item.openTarget)
    }

    func testOpenOptionRoundTrips() throws {
        var item = DockItem.application(bundleIdentifier: "com.a", path: "/Applications/A.app", displayName: "A")
        item.opensWhenUsed = true
        item.openTarget = "https://example.com"
        let data = try JSONEncoder().encode(item)
        let decoded = try decoder.decode(DockItem.self, from: data)
        XCTAssertEqual(decoded.opensWhenUsed, true)
        XCTAssertEqual(decoded.openTarget, "https://example.com")
    }

    func testVersionFourFileKeepsRulesAndKeepOpenList() throws {
        var library = DockLibrary(profiles: [DockProfile(name: "Main")])
        library.displayRules = [DisplayRule(setKey: "k", setName: "Studio", profileID: library.profiles[0].id)]
        library.alwaysKeepOpen = [KeepOpenApp(bundleIdentifier: "com.keep", name: "Keep")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoded = try decoder.decode(DockLibrary.self, from: encoder.encode(library))
        XCTAssertEqual(decoded.schemaVersion, 4)
        XCTAssertEqual(decoded.displayRules?.first?.setKey, "k")
        XCTAssertEqual(decoded.alwaysKeepOpen?.first?.bundleIdentifier, "com.keep")
    }

    func testVersionThreeFileMigratesToFour() {
        var library = DockLibrary(profiles: [DockProfile(name: "Main", otherItems: [])])
        library.schemaVersion = 3
        library.migrate(currentOthers: { [] })
        XCTAssertEqual(library.schemaVersion, 4)
        XCTAssertNil(library.displayRules)
    }

    func testQuitOptionIsOffForOldDocks() throws {
        let json = #"{"color":{"hex":"0A84FF"},"createdAt":"2026-09-06T10:00:00Z","id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","items":[],"name":"Old","updatedAt":"2026-09-06T10:00:00Z"}"#
        let profile = try decoder.decode(DockProfile.self, from: Data(json.utf8))
        XCTAssertNil(profile.quitOthersOnSwitch)
    }
}
