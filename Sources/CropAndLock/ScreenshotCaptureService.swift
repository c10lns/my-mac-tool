import Foundation

enum ScreenshotCaptureError: Error, LocalizedError {
    case alreadyCapturing
    case cancelled
    case launchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing:
            return "A screenshot capture is already in progress."
        case .cancelled:
            return "Screenshot capture was cancelled."
        case .launchFailed(let error):
            return "Could not start screenshot capture: \(error.localizedDescription)"
        }
    }
}

final class ScreenshotCaptureService {
    private let fileFactory: ScreenshotFileFactory
    private var isCapturing = false

    init(fileFactory: ScreenshotFileFactory = ScreenshotFileFactory()) {
        self.fileFactory = fileFactory
    }

    func capture(completion: @escaping (Result<URL, ScreenshotCaptureError>) -> Void) {
        guard !isCapturing else {
            completion(.failure(.alreadyCapturing))
            return
        }

        isCapturing = true

        let outputURL: URL
        do {
            outputURL = try fileFactory.makeScreenshotURL()
        } catch {
            isCapturing = false
            completion(.failure(.launchFailed(error)))
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", outputURL.path]

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.isCapturing = false

                if Self.hasUsableImage(at: outputURL) {
                    completion(.success(outputURL))
                } else {
                    try? self.fileFactory.removeGeneratedFile(at: outputURL)
                    completion(.failure(.cancelled))
                }
            }
        }

        do {
            try process.run()
        } catch {
            isCapturing = false
            try? fileFactory.removeGeneratedFile(at: outputURL)
            completion(.failure(.launchFailed(error)))
        }
    }

    private static func hasUsableImage(at url: URL) -> Bool {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return false
        }

        return size.intValue > 0
    }
}
