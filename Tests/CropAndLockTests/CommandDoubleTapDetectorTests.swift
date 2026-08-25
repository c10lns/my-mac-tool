import AppKit
import XCTest
@testable import CropAndLock

final class CommandOptionChordDetectorTests: XCTestCase {
    func testCommandThenOptionTriggersOnceWhenBothArePressed() {
        var detector = CommandOptionChordDetector()

        XCTAssertFalse(detector.modifierFlagsChanged(to: [.command]))
        XCTAssertTrue(detector.modifierFlagsChanged(to: [.command, .option]))
        XCTAssertFalse(detector.modifierFlagsChanged(to: [.command, .option]))
    }

    func testOptionThenCommandTriggersOnceWhenBothArePressed() {
        var detector = CommandOptionChordDetector()

        XCTAssertFalse(detector.modifierFlagsChanged(to: [.option]))
        XCTAssertTrue(detector.modifierFlagsChanged(to: [.command, .option]))
        XCTAssertFalse(detector.modifierFlagsChanged(to: [.command, .option]))
    }

    func testReleasingARequiredModifierAllowsNextChordToTrigger() {
        var detector = CommandOptionChordDetector()

        XCTAssertTrue(detector.modifierFlagsChanged(to: [.command, .option]))
        XCTAssertFalse(detector.modifierFlagsChanged(to: [.command]))
        XCTAssertTrue(detector.modifierFlagsChanged(to: [.command, .option]))
    }

    func testSingleModifierDoesNotTrigger() {
        var detector = CommandOptionChordDetector()

        XCTAssertFalse(detector.modifierFlagsChanged(to: [.command]))
        XCTAssertFalse(detector.modifierFlagsChanged(to: [.option]))
    }
}
