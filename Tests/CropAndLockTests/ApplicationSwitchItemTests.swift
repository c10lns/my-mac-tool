import XCTest
@testable import CropAndLock

final class ApplicationSwitchItemTests: XCTestCase {
    func testSortedByRecentActivationKeepsNewestFirst() {
        let older = ApplicationSwitchItem(
            name: "Older",
            bundleIdentifier: "test.older",
            processIdentifier: 1,
            icon: nil,
            lastActivationDate: Date(timeIntervalSince1970: 10)
        )
        let newer = ApplicationSwitchItem(
            name: "Newer",
            bundleIdentifier: "test.newer",
            processIdentifier: 2,
            icon: nil,
            lastActivationDate: Date(timeIntervalSince1970: 20)
        )

        XCTAssertEqual([older, newer].sortedForSwitcher().map(\.name), ["Newer", "Older"])
    }

    func testSortedByRecentActivationFallsBackToName() {
        let safari = ApplicationSwitchItem(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            processIdentifier: 1,
            icon: nil,
            lastActivationDate: nil
        )
        let finder = ApplicationSwitchItem(
            name: "Finder",
            bundleIdentifier: "com.apple.finder",
            processIdentifier: 2,
            icon: nil,
            lastActivationDate: nil
        )

        XCTAssertEqual([safari, finder].sortedForSwitcher().map(\.name), ["Finder", "Safari"])
    }
}
