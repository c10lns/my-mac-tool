import Foundation

enum ScreenshotCaptureError: Error, LocalizedError {
    case alreadyCapturing
    case cancelled
    case launchFailed(Error)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing:
            return "A screenshot capture is already in progress."
        case .cancelled:
            return "Screenshot capture was cancelled."
        case .launchFailed(let error):
            return "Could not start screenshot capture: \(error.localizedDescription)"
        case .commandFailed(let message):
            return "Screenshot capture failed: \(message)"
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
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = Self.screencaptureArguments(for: outputURL)
        process.standardError = standardError

        process.terminationHandler = { [weak self] _ in
            let errorOutput = Self.stringOutput(from: standardError)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.isCapturing = false

                if Self.hasUsableImage(at: outputURL) {
                    completion(.success(outputURL))
                } else {
                    try? self.fileFactory.removeGeneratedFile(at: outputURL)
                    completion(.failure(Self.captureFailure(from: errorOutput)))
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

    static func screencaptureArguments(for outputURL: URL) -> [String] {
        ["-i", "-s", "-x", "-t", "png", outputURL.path]
    }

    private static func captureFailure(from errorOutput: String) -> ScreenshotCaptureError {
        let message = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? .cancelled : .commandFailed(message)
    }

    private static func stringOutput(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
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
