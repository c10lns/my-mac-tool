import XCTest
@testable import CropAndLock

final class ApplicationActivationHistoryTests: XCTestCase {
    func testPreferredSwitcherApplicationReturnsPreviousApplicationBeforeCurrent() {
        let history = ApplicationActivationHistory(ownBundleIdentifier: "local.cropandlock.app")
        history.record(bundleIdentifier: "app.a")
        history.record(bundleIdentifier: "app.b")

        let preferred = history.preferredSwitcherBundleIdentifier(
            currentBundleIdentifier: "app.b",
            availableBundleIdentifiers: Set(["app.a", "app.b"])
        )

        XCTAssertEqual(preferred, "app.a")
    }

    func testPreferredSwitcherApplicationIgnoresUnavailableAndOwnApplication() {
        let history = ApplicationActivationHistory(ownBundleIdentifier: "local.cropandlock.app")
        history.record(bundleIdentifier: "app.a")
        history.record(bundleIdentifier: "local.cropandlock.app")
        history.record(bundleIdentifier: "app.b")

        let preferred = history.preferredSwitcherBundleIdentifier(
            currentBundleIdentifier: "app.b",
            availableBundleIdentifiers: Set(["app.b"])
        )

        XCTAssertNil(preferred)
    }
}
