import Foundation

enum AppSettings {
    static let appName = "CropAndLock"
    static let defaultHotKeyLabel = "command+control+a"
    static let switcherHotKeyLabel = "command+option"
    static let captureDirectoryName = "CropAndLock"
}

struct ScreenshotFileFactory {
    let directory: URL
    private let fileManager: FileManager

    init(
        directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(AppSettings.captureDirectoryName, isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func makeScreenshotURL() throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("capture-\(UUID().uuidString).png")
    }

    func removeGeneratedFile(at url: URL) throws {
        guard url.deletingLastPathComponent() == directory else {
            return
        }

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
