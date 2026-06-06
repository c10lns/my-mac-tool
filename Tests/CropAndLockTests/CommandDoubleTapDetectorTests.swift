import XCTest
@testable import CropAndLock

final class CommandDoubleTapDetectorTests: XCTestCase {
    func testDoubleCommandWithoutInterruptionTriggers() {
        var detector = CommandDoubleTapDetector(interval: 0.42, maximumTapDuration: 0.2)

        detector.commandKeyDown(at: 1.0)
        XCTAssertFalse(detector.commandKeyUp(at: 1.08))

        detector.commandKeyDown(at: 1.2)
        XCTAssertTrue(detector.commandKeyUp(at: 1.28))
    }

    func testOtherKeyBetweenCommandPressesCancelsDoubleTap() {
        var detector = CommandDoubleTapDetector(interval: 0.42, maximumTapDuration: 0.2)

        detector.commandKeyDown(at: 1.0)
        XCTAssertFalse(detector.commandKeyUp(at: 1.08))

        detector.interrupt()

        detector.commandKeyDown(at: 1.2)
        XCTAssertFalse(detector.commandKeyUp(at: 1.28))
    }

    func testMouseClickBetweenCommandPressesCancelsDoubleTap() {
        var detector = CommandDoubleTapDetector(interval: 0.42, maximumTapDuration: 0.2)

        detector.commandKeyDown(at: 1.0)
        XCTAssertFalse(detector.commandKeyUp(at: 1.08))

        detector.interrupt()

        detector.commandKeyDown(at: 1.2)
        XCTAssertFalse(detector.commandKeyUp(at: 1.28))
    }

    func testCommandPressAfterIntervalStartsNewSequence() {
        var detector = CommandDoubleTapDetector(interval: 0.42, maximumTapDuration: 0.2)

        detector.commandKeyDown(at: 1.0)
        XCTAssertFalse(detector.commandKeyUp(at: 1.08))

        detector.commandKeyDown(at: 1.8)
        XCTAssertFalse(detector.commandKeyUp(at: 1.88))
    }

    func testLongCommandHoldDoesNotCountAsTap() {
        var detector = CommandDoubleTapDetector(interval: 0.42, maximumTapDuration: 0.2)

        detector.commandKeyDown(at: 1.0)
        XCTAssertFalse(detector.commandKeyUp(at: 1.5))

        detector.commandKeyDown(at: 1.6)
        XCTAssertFalse(detector.commandKeyUp(at: 1.68))
    }

    func testCommandShortcutDuringHoldCancelsPotentialTap() {
        var detector = CommandDoubleTapDetector(interval: 0.42, maximumTapDuration: 0.2)

        detector.commandKeyDown(at: 1.0)
        detector.interrupt()
        XCTAssertFalse(detector.commandKeyUp(at: 1.08))

        detector.commandKeyDown(at: 1.2)
        XCTAssertFalse(detector.commandKeyUp(at: 1.28))
    }
}
