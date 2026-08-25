import AppKit
import ApplicationServices
import Foundation

struct CommandOptionChordDetector {
    private var wasChordDown = false

    mutating func modifierFlagsChanged(to flags: NSEvent.ModifierFlags) -> Bool {
        let normalizedFlags = flags.intersection(.deviceIndependentFlagsMask)
        let chordIsDown = normalizedFlags.contains(.command) && normalizedFlags.contains(.option)

        defer {
            wasChordDown = chordIsDown
        }

        return chordIsDown && !wasChordDown
    }
}

final class CommandOptionChordMonitor {
    private let onChord: () -> Void
    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []
    private var detector = CommandOptionChordDetector()

    init(onChord: @escaping () -> Void) {
        self.onChord = onChord
    }

    func start() {
        _ = AXIsProcessTrusted()

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handle(event)
        }) {
            globalMonitors.append(monitor)
        }

        if let localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            localMonitors.append(localFlagsMonitor)
        }
    }

    func stop() {
        for monitor in globalMonitors {
            NSEvent.removeMonitor(monitor)
        }

        for monitor in localMonitors {
            NSEvent.removeMonitor(monitor)
        }

        globalMonitors = []
        localMonitors = []
    }

    deinit {
        stop()
    }

    private func handle(_ event: NSEvent) {
        if detector.modifierFlagsChanged(to: event.modifierFlags) {
            onChord()
        }
    }
}
