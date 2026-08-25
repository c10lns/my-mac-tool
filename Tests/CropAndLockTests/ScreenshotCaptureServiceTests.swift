import XCTest
@testable import CropAndLock

final class ScreenshotCaptureServiceTests: XCTestCase {
    func testScreencaptureArgumentsForceInteractiveRegionPng() {
        let outputURL = URL(fileURLWithPath: "/tmp/capture.png")

        XCTAssertEqual(
            ScreenshotCaptureService.screencaptureArguments(for: outputURL),
            ["-i", "-s", "-x", "-t", "png", "/tmp/capture.png"]
        )
    }

    func testScreencaptureErrorIncludesCommandOutput() {
        let error = ScreenshotCaptureError.commandFailed("could not create image from rect")

        XCTAssertEqual(error.errorDescription, "Screenshot capture failed: could not create image from rect")
    }
}
