import XCTest
@testable import Docksly

final class DockApplicatorReadTests: XCTestCase {
    func testEmptyArrayIsARealEmptyDock() throws {
        let tiles = try DockApplicator.decodePersistentArray([] as [Any])
        XCTAssertEqual(tiles.count, 0)
    }

    func testMissingValueIsUnreadable() {
        XCTAssertThrowsError(try DockApplicator.decodePersistentArray(nil)) { error in
            XCTAssertEqual(error as? DockApplicatorError, .preferenceReadFailed)
        }
    }

    func testNonArrayValueIsUnreadable() {
        XCTAssertThrowsError(try DockApplicator.decodePersistentArray("not an array"))
        XCTAssertThrowsError(try DockApplicator.decodePersistentArray(1))
        XCTAssertThrowsError(try DockApplicator.decodePersistentArray(["tile-type": "file-tile"]))
    }

    func testArrayOfTilesSucceeds() throws {
        let raw: [Any] = [
            ["tile-type": "spacer-tile", "tile-data": [String: Any]()]
        ]
        let tiles = try DockApplicator.decodePersistentArray(raw)
        XCTAssertEqual(tiles.count, 1)
        XCTAssertEqual(tiles[0]["tile-type"] as? String, "spacer-tile")
    }

    func testArrayWithANonDictionaryIsUnreadable() {
        let raw: [Any] = [
            ["tile-type": "spacer-tile"],
            "bad"
        ]
        XCTAssertThrowsError(try DockApplicator.decodePersistentArray(raw)) { error in
            XCTAssertEqual(error as? DockApplicatorError, .preferenceReadFailed)
        }
    }
}
