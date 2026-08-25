import XCTest
@testable import CropAndLock

final class AppSettingsTests: XCTestCase {
    func testDefaultHotKeyLabelIsCommandControlA() {
        XCTAssertEqual(AppSettings.defaultHotKeyLabel, "command+control+a")
    }

    func testSwitcherHotKeyLabelIsCommandOption() {
        XCTAssertEqual(AppSettings.switcherHotKeyLabel, "command+option")
    }

    func testScreenshotFileFactoryCreatesPngInsideConfiguredDirectory() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CropAndLockTests-\(UUID().uuidString)", isDirectory: true)
        let factory = ScreenshotFileFactory(directory: directory)

        let url = try factory.makeScreenshotURL()

        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("capture-"))
        XCTAssertEqual(url.deletingLastPathComponent(), directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    func testScreenshotFileFactoryRemovesOnlyGeneratedFile() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CropAndLockTests-\(UUID().uuidString)", isDirectory: true)
        let factory = ScreenshotFileFactory(directory: directory)
        let generated = try factory.makeScreenshotURL()
        let unrelated = directory.appendingPathComponent("keep.txt")

        try Data("generated".utf8).write(to: generated)
        try Data("keep".utf8).write(to: unrelated)

        try factory.removeGeneratedFile(at: generated)

        XCTAssertFalse(FileManager.default.fileExists(atPath: generated.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }
}
