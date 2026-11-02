import XCTest
@testable import Docksly

final class TrialClockTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testTrialLastsSevenDays() {
        XCTAssertEqual(LicenseStore.trialDuration, 7 * 24 * 60 * 60)
    }

    func testRecordWithLicenseDecodes() throws {
        let record = LicenseRecord(trialStartedAt: start, licenseCode: "KEY", isLicensed: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LicenseRecord.self, from: encoder.encode(record))
        XCTAssertTrue(decoded.isLicensed)
        XCTAssertEqual(decoded.trialStartedAt, start)
    }

    func testRemainingTextUsesDaysThenHoursThenMinutes() {
        let end = start.addingTimeInterval(LicenseStore.trialDuration)
        func text(_ secondsLeft: TimeInterval) -> String {
            LicenseStore.trialRemainingText(endsAt: end, now: end.addingTimeInterval(-secondsLeft))
        }
        XCTAssertEqual(text(LicenseStore.trialDuration), "Trial · 7 days left")
        XCTAssertEqual(text(2 * 86_400 + 5), "Trial · 2 days left")
        XCTAssertEqual(text(86_400 + 3600), "Trial · 1 day left")
        XCTAssertEqual(text(5 * 3600), "Trial · 5 hours left")
        XCTAssertEqual(text(3600), "Trial · 1 hour left")
        XCTAssertEqual(text(120), "Trial · 2 minutes left")
        XCTAssertEqual(text(30), "Trial · less than 1 minute left")
        XCTAssertEqual(text(0), "Trial ended")
        XCTAssertEqual(text(-10), "Trial ended")
    }

    /// A 1.0.x user whose 24-hour trial started 3 days ago is inside the 7-day trial again.
    func testOldTrialStartIsInsideSevenDays() {
        let now = start.addingTimeInterval(3 * 86_400)
        let end = start.addingTimeInterval(LicenseStore.trialDuration)
        XCTAssertTrue(now < end)
        XCTAssertEqual(LicenseStore.trialRemainingText(endsAt: end, now: now), "Trial · 4 days left")
    }
}
