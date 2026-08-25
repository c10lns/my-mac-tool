import AppKit
import XCTest
@testable import CropAndLock

final class ApplicationSwitcherSelectionModelTests: XCTestCase {
    func testDefaultSelectionUsesMostRecentApplication() {
        let older = ApplicationSwitcherSelectionEntry(
            identifier: "older",
            displayName: "Older",
            center: NSPoint(x: 0, y: 0),
            lastActivationDate: Date(timeIntervalSince1970: 10)
        )
        let newer = ApplicationSwitcherSelectionEntry(
            identifier: "newer",
            displayName: "Newer",
            center: NSPoint(x: 100, y: 0),
            lastActivationDate: Date(timeIntervalSince1970: 20)
        )

        let model = ApplicationSwitcherSelectionModel(entries: [older, newer])

        XCTAssertEqual(model.selectedIdentifier, "newer")
    }

    func testPreferredSelectionUsesPreviousApplicationEvenWhenCurrentIsNewer() {
        let previous = ApplicationSwitcherSelectionEntry(
            identifier: "previous",
            displayName: "Previous",
            center: NSPoint(x: 0, y: 0),
            lastActivationDate: Date(timeIntervalSince1970: 10)
        )
        let current = ApplicationSwitcherSelectionEntry(
            identifier: "current",
            displayName: "Current",
            center: NSPoint(x: 100, y: 0),
            lastActivationDate: Date(timeIntervalSince1970: 20)
        )

        let model = ApplicationSwitcherSelectionModel(
            entries: [previous, current],
            preferredIdentifier: "previous"
        )

        XCTAssertEqual(model.selectedIdentifier, "previous")
    }

    func testDefaultSelectionFallsBackToFirstEntryWhenNoRecencyExists() {
        let first = ApplicationSwitcherSelectionEntry(identifier: "first", displayName: "First", center: NSPoint(x: 0, y: 0), lastActivationDate: nil)
        let second = ApplicationSwitcherSelectionEntry(identifier: "second", displayName: "Second", center: NSPoint(x: 100, y: 0), lastActivationDate: nil)

        let model = ApplicationSwitcherSelectionModel(entries: [first, second])

        XCTAssertEqual(model.selectedIdentifier, "first")
    }

    func testSelectedDisplayNameFollowsSelectedEntry() {
        let first = ApplicationSwitcherSelectionEntry(identifier: "first", displayName: "First App", center: NSPoint(x: 0, y: 0), lastActivationDate: nil)
        let second = ApplicationSwitcherSelectionEntry(identifier: "second", displayName: "Second App", center: NSPoint(x: 100, y: 0), lastActivationDate: nil)
        var model = ApplicationSwitcherSelectionModel(entries: [first, second])

        model.move(.right)

        XCTAssertEqual(model.selectedDisplayName, "Second App")
    }

    func testDirectionalMoveSelectsNearestApplicationInRequestedDirection() {
        let current = ApplicationSwitcherSelectionEntry(identifier: "current", displayName: "Current", center: NSPoint(x: 0, y: 0), lastActivationDate: nil)
        let right = ApplicationSwitcherSelectionEntry(identifier: "right", displayName: "Right", center: NSPoint(x: 100, y: 0), lastActivationDate: nil)
        let fartherRight = ApplicationSwitcherSelectionEntry(identifier: "fartherRight", displayName: "Farther Right", center: NSPoint(x: 200, y: 20), lastActivationDate: nil)
        var model = ApplicationSwitcherSelectionModel(entries: [current, right, fartherRight])

        model.move(.right)

        XCTAssertEqual(model.selectedIdentifier, "right")
    }

    func testDirectionalMoveFiltersBySideThenChoosesClosestCenterDistance() {
        let current = ApplicationSwitcherSelectionEntry(identifier: "current", displayName: "Current", center: NSPoint(x: 100, y: 100), lastActivationDate: nil)
        let nearestLeft = ApplicationSwitcherSelectionEntry(identifier: "nearestLeft", displayName: "Nearest Left", center: NSPoint(x: 70, y: 120), lastActivationDate: nil)
        let fartherLeft = ApplicationSwitcherSelectionEntry(identifier: "fartherLeft", displayName: "Farther Left", center: NSPoint(x: 0, y: 100), lastActivationDate: nil)
        let wrongSide = ApplicationSwitcherSelectionEntry(identifier: "wrongSide", displayName: "Wrong Side", center: NSPoint(x: 130, y: 100), lastActivationDate: nil)
        var model = ApplicationSwitcherSelectionModel(entries: [current, nearestLeft, fartherLeft, wrongSide])

        model.move(.left)

        XCTAssertEqual(model.selectedIdentifier, "nearestLeft")
    }

    func testDirectionalMoveKeepsSelectionWhenNoCandidateExistsOnRequestedSide() {
        let left = ApplicationSwitcherSelectionEntry(identifier: "left", displayName: "Left", center: NSPoint(x: 0, y: 0), lastActivationDate: nil)
        let middle = ApplicationSwitcherSelectionEntry(identifier: "middle", displayName: "Middle", center: NSPoint(x: 100, y: 0), lastActivationDate: nil)
        let right = ApplicationSwitcherSelectionEntry(identifier: "right", displayName: "Right", center: NSPoint(x: 200, y: 0), lastActivationDate: nil)
        var model = ApplicationSwitcherSelectionModel(entries: [left, middle, right])

        model.move(.right)
        XCTAssertEqual(model.selectedIdentifier, "middle")

        model.move(.right)
        XCTAssertEqual(model.selectedIdentifier, "right")

        model.move(.right)
        XCTAssertEqual(model.selectedIdentifier, "right")
    }
}
