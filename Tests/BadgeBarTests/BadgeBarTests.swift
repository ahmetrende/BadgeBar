import XCTest
@testable import BadgeBar

final class BadgeBarTests: XCTestCase {
    // MARK: - New-message detection

    func testAppearanceFires() {
        XCTAssertTrue(BadgeMonitor.isNewMessage(old: "", new: "1"))
        XCTAssertTrue(BadgeMonitor.isNewMessage(old: "", new: "12"))
    }

    func testNumericIncreaseFires() {
        XCTAssertTrue(BadgeMonitor.isNewMessage(old: "2", new: "5"))
        XCTAssertTrue(BadgeMonitor.isNewMessage(old: "5", new: "9+"))   // 5 -> 9
        XCTAssertTrue(BadgeMonitor.isNewMessage(old: "9", new: "10"))
    }

    func testDecreaseOrSameDoesNotFire() {
        XCTAssertFalse(BadgeMonitor.isNewMessage(old: "5", new: "2"))
        XCTAssertFalse(BadgeMonitor.isNewMessage(old: "3", new: "3"))
        XCTAssertFalse(BadgeMonitor.isNewMessage(old: "1", new: ""))    // cleared
    }

    func testNonNumericChangeFires() {
        XCTAssertTrue(BadgeMonitor.isNewMessage(old: "A", new: "B"))
        XCTAssertFalse(BadgeMonitor.isNewMessage(old: "A", new: "A"))
    }

    // MARK: - Version comparison

    func testVersionComparison() {
        XCTAssertTrue(UpdateChecker.isNewer("1.0.2", than: "1.0.1"))
        XCTAssertTrue(UpdateChecker.isNewer("1.1.0", than: "1.0.9"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0.10", than: "1.0.9"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.1", than: "1.0.1"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0.1"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0", than: "1.0.0"))
    }

    // MARK: - MonitoredApp overrides & persistence

    func testOverrideDefaults() {
        let app = MonitoredApp(bundleId: "a", name: "A", titles: ["A"])
        XCTAssertNil(app.showCountOverride)
        XCTAssertNil(app.alertOverride)
        XCTAssertTrue(app.showsCount(default: true))
        XCTAssertFalse(app.showsCount(default: false))
    }

    func testOverrideWins() {
        var app = MonitoredApp(bundleId: "a", name: "A", titles: ["A"])
        app.showCountOverride = false
        XCTAssertFalse(app.showsCount(default: true))
        app.alertOverride = true
        XCTAssertTrue(app.alerts(default: false))
    }

    func testDecodesLegacyJSONWithoutOverrides() throws {
        let json = Data(#"{"bundleId":"x","name":"X","titles":["X"]}"#.utf8)
        let app = try JSONDecoder().decode(MonitoredApp.self, from: json)
        XCTAssertEqual(app.bundleId, "x")
        XCTAssertEqual(app.titles, ["X"])
        XCTAssertNil(app.showCountOverride)
        XCTAssertNil(app.alertOverride)
    }
}
