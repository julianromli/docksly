import XCTest
@testable import Docksly

final class LibraryMigrationTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// A library file as Docksly 1.0.x wrote it: no schema version, no Focus field.
    private let legacyJSON = """
    {
      "activeProfileID" : "6F9619FF-8B86-D011-B42D-00C04FC964FF",
      "lastAppliedSignature" : "app:com.apple.Safari",
      "profiles" : [
        {
          "color" : { "hex" : "0A84FF" },
          "createdAt" : "2026-09-06T10:00:00Z",
          "id" : "6F9619FF-8B86-D011-B42D-00C04FC964FF",
          "items" : [
            {
              "bookmarkPath" : "/Applications/Safari.app",
              "bundleIdentifier" : "com.apple.Safari",
              "displayName" : "Safari",
              "id" : "0E1D2C3B-4A59-6877-8695-A4B3C2D1E0F9",
              "kind" : "application"
            }
          ],
          "name" : "Main",
          "updatedAt" : "2026-09-06T10:00:00Z"
        }
      ]
    }
    """

    func testLegacyFileReadsAsVersionOne() throws {
        let library = try decoder().decode(DockLibrary.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(library.schemaVersion, 1)
        XCTAssertNil(library.focusRestoreProfileID)
        XCTAssertEqual(library.profiles.count, 1)
        XCTAssertEqual(library.profiles[0].items.first?.bundleIdentifier, "com.apple.Safari")
    }

    func testMigrateBringsLegacyFileToCurrentVersion() throws {
        var library = try decoder().decode(DockLibrary.self, from: Data(legacyJSON.utf8))
        let before = library.profiles
        library.migrate()
        XCTAssertEqual(library.schemaVersion, DockLibrary.currentSchemaVersion)
        XCTAssertEqual(library.profiles, before)
    }

    func testRoundTripKeepsNewFields() throws {
        let restore = UUID()
        let library = DockLibrary(profiles: [DockProfile(name: "Work")], focusRestoreProfileID: restore)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoded = try decoder().decode(DockLibrary.self, from: encoder.encode(library))
        XCTAssertEqual(decoded.schemaVersion, DockLibrary.currentSchemaVersion)
        XCTAssertEqual(decoded.focusRestoreProfileID, restore)
    }

    func testRemovingDockClearsFocusRestoreTarget() {
        let work = DockProfile(name: "Work")
        var library = DockLibrary(profiles: [work, DockProfile(name: "Main")], focusRestoreProfileID: work.id)
        library.remove(id: work.id)
        XCTAssertNil(library.focusRestoreProfileID)
    }
}
