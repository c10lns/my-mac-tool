import AppKit
import XCTest
@testable import CropAndLock

final class ApplicationSwitcherDismissDetectorTests: XCTestCase {
    func testReleasingOptionFromOpeningChordDoesNotDismissWhileCommandRemainsDown() {
        var detector = ApplicationSwitcherDismissDetector(initialModifierFlags: [.command, .option])

        XCTAssertFalse(detector.modifierFlagsChanged(to: [.command]))
    }

    func testCommandPressDismissesAfterOpeningChordHasBeenReleased() {
        var detector = ApplicationSwitcherDismissDetector(initialModifierFlags: [.command, .option])

        XCTAssertFalse(detector.modifierFlagsChanged(to: [.command]))
        XCTAssertFalse(detector.modifierFlagsChanged(to: []))
        XCTAssertTrue(detector.modifierFlagsChanged(to: [.command]))
    }

    func testCommandPressDismissesWhenSwitcherWasOpenedWithoutCommandHeld() {
        var detector = ApplicationSwitcherDismissDetector(initialModifierFlags: [])

        XCTAssertTrue(detector.modifierFlagsChanged(to: [.command]))
    }
}
