import XCTest
@testable import Docksly

final class DockTileEncodingTests: XCTestCase {
    func testFolderTileRoundTrip() throws {
        let folder = DockOtherItem.folder(path: "/Users/me/Projects", label: "Projects", display: .stack, sort: .name, view: .list)
        let tile = try XCTUnwrap(DockApplicator.makeOtherTile(from: folder))
        XCTAssertEqual(tile["tile-type"] as? String, "directory-tile")
        let data = try XCTUnwrap(tile["tile-data"] as? [String: Any])
        XCTAssertEqual(data["displayas"] as? Int, 0)
        XCTAssertEqual(data["arrangement"] as? Int, 1)
        XCTAssertEqual(data["showas"] as? Int, 3)
        XCTAssertEqual(data["file-type"] as? Int, 2)
        let fileData = try XCTUnwrap(data["file-data"] as? [String: Any])
        XCTAssertEqual(fileData["_CFURLString"] as? String, "file:///Users/me/Projects/")
        XCTAssertEqual(fileData["_CFURLStringType"] as? Int, 15)

        let parsed = try XCTUnwrap(DockApplicator.parseOtherTile(tile))
        XCTAssertEqual(parsed.kind, .folder)
        XCTAssertEqual(parsed.layoutSignature, folder.layoutSignature)
        XCTAssertEqual(parsed.title, "Projects")
    }

    func testFileTileRoundTrip() throws {
        let file = DockOtherItem.file(path: "/Users/me/Notes.txt")
        let tile = try XCTUnwrap(DockApplicator.makeOtherTile(from: file))
        XCTAssertEqual(tile["tile-type"] as? String, "file-tile")
        let parsed = try XCTUnwrap(DockApplicator.parseOtherTile(tile))
        XCTAssertEqual(parsed.kind, .file)
        XCTAssertEqual(parsed.layoutSignature, file.layoutSignature)
    }

    func testLinkTileRoundTrip() throws {
        let link = DockOtherItem.link(url: "https://example.com/docs", label: "Docs")
        let tile = try XCTUnwrap(DockApplicator.makeOtherTile(from: link))
        XCTAssertEqual(tile["tile-type"] as? String, "url-tile")
        let data = try XCTUnwrap(tile["tile-data"] as? [String: Any])
        XCTAssertEqual(data["label"] as? String, "Docs")
        let parsed = try XCTUnwrap(DockApplicator.parseOtherTile(tile))
        XCTAssertEqual(parsed.kind, .link)
        XCTAssertEqual(parsed.url, "https://example.com/docs")
        XCTAssertEqual(parsed.title, "Docs")
    }

    /// The Downloads tile as macOS writes it (copied from a real Dock, bookmark removed).
    func testReadsTheSystemDownloadsTile() throws {
        let tile: [String: Any] = [
            "tile-type": "directory-tile",
            "tile-data": [
                "showas": 2, "file-type": 2, "preferreditemsize": -1, "displayas": 0,
                "file-label": "Downloads", "arrangement": 2, "is-beta": false,
                "file-data": ["_CFURLStringType": 15, "_CFURLString": "file:///Users/me/Downloads/"],
            ] as [String: Any],
        ]
        let parsed = try XCTUnwrap(DockApplicator.parseOtherTile(tile))
        XCTAssertEqual(parsed.path, "/Users/me/Downloads")
        XCTAssertEqual(parsed.display, .stack)
        XCTAssertEqual(parsed.sort, .dateAdded)
        XCTAssertEqual(parsed.view, .grid)
    }

    func testUnknownTileTypesAreSkipped() {
        XCTAssertNil(DockApplicator.parseOtherTile(["tile-type": "recents-tile", "tile-data": [String: Any]()]))
        XCTAssertNil(DockApplicator.makeOtherTile(from: .link(url: "")))
        XCTAssertNil(DockApplicator.makeOtherTile(from: .file(path: "")))
    }

    func testSignatureIgnoresCaseAndTrailingSlash() {
        XCTAssertEqual(
            DockOtherItem.folder(path: "/Users/Me/Downloads/").layoutSignature,
            DockOtherItem.folder(path: "/users/me/Downloads").layoutSignature
        )
        XCTAssertNotEqual(
            DockOtherItem.folder(path: "/a", display: .stack).layoutSignature,
            DockOtherItem.folder(path: "/a", display: .folder).layoutSignature
        )
    }

    func testWholeDockSignatureSeparatesBothSides() {
        let apps = [DockItem.spacer()]
        XCTAssertNotEqual(
            DockLayout.signature(apps: apps, others: []),
            DockLayout.signature(apps: apps, others: [.link(url: "https://a.com")])
        )
    }

    func testLinkAddressNormalization() {
        XCTAssertEqual(DockOtherItem.normalizedLinkURL("example.com"), "https://example.com")
        XCTAssertEqual(DockOtherItem.normalizedLinkURL("  https://example.com/x  "), "https://example.com/x")
        XCTAssertEqual(DockOtherItem.normalizedLinkURL("vnc://server.local"), "vnc://server.local")
        XCTAssertEqual(DockOtherItem.normalizedLinkURL("localhost:3000"), "https://localhost:3000")
        XCTAssertNil(DockOtherItem.normalizedLinkURL(""))
        XCTAssertNil(DockOtherItem.normalizedLinkURL("not a url"))
        XCTAssertNil(DockOtherItem.normalizedLinkURL("hello"))
    }

    func testAppearanceValuesAreClamped() {
        var appearance = DockAppearance.systemDefault
        appearance.isEnabled = true
        appearance.tileSize = 400
        appearance.largeSize = 2
        appearance.position = .left
        let values = Dictionary(uniqueKeysWithValues: DockApplicator.appearanceValues(appearance).map { ($0.0, $0.1) })
        XCTAssertEqual((values["tilesize"] as? NSNumber)?.doubleValue, 128)
        XCTAssertEqual((values["largesize"] as? NSNumber)?.doubleValue, 16)
        XCTAssertEqual(values["orientation"] as? String, "left")
        XCTAssertEqual((values["show-recents"] as? NSNumber)?.boolValue, true)
    }
}
