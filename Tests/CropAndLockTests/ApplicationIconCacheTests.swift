import AppKit
import XCTest
@testable import CropAndLock

final class ApplicationIconCacheTests: XCTestCase {
    func testIconIsLoadedOnlyOnceForTheSameBundleIdentifier() {
        let cache = ApplicationIconCache()
        var loadCount = 0

        let first = cache.icon(forBundleIdentifier: "test.app") {
            loadCount += 1
            return NSImage(size: NSSize(width: 16, height: 16))
        }
        let second = cache.icon(forBundleIdentifier: "test.app") {
            loadCount += 1
            return NSImage(size: NSSize(width: 32, height: 32))
        }

        guard let first, let second else {
            XCTFail("Expected cached icons to be available")
            return
        }

        XCTAssertTrue(first === second)
        XCTAssertEqual(loadCount, 1)
    }

    func testMissingBundleIdentifierDoesNotCacheIcon() {
        let cache = ApplicationIconCache()
        var loadCount = 0

        _ = cache.icon(forBundleIdentifier: nil) {
            loadCount += 1
            return NSImage(size: NSSize(width: 16, height: 16))
        }
        _ = cache.icon(forBundleIdentifier: nil) {
            loadCount += 1
            return NSImage(size: NSSize(width: 32, height: 32))
        }

        XCTAssertEqual(loadCount, 2)
    }
}
