import AppKit
import ApplicationServices
import Foundation

struct CommandDoubleTapDetector {
    let interval: TimeInterval
    let maximumTapDuration: TimeInterval
    private var lastCommandTap: TimeInterval?
    private var commandDownAt: TimeInterval?
    private var currentPressWasInterrupted = false

    init(interval: TimeInterval, maximumTapDuration: TimeInterval) {
        self.interval = interval
        self.maximumTapDuration = maximumTapDuration
    }

    mutating func commandKeyDown(at time: TimeInterval) {
        guard commandDownAt == nil else {
            return
        }

        commandDownAt = time
        currentPressWasInterrupted = false
    }

    mutating func commandKeyUp(at time: TimeInterval) -> Bool {
        guard let commandDownAt else {
            return false
        }

        defer {
            self.commandDownAt = nil
            currentPressWasInterrupted = false
        }

        guard !currentPressWasInterrupted else {
            lastCommandTap = nil
            return false
        }

        guard time - commandDownAt <= maximumTapDuration else {
            lastCommandTap = nil
            return false
        }

        guard let lastCommandTap else {
            self.lastCommandTap = time
            return false
        }

        guard time - lastCommandTap <= interval else {
            self.lastCommandTap = time
            return false
        }

        self.lastCommandTap = nil
        return true
    }

    mutating func interrupt() {
        lastCommandTap = nil
        if commandDownAt != nil {
            currentPressWasInterrupted = true
        }
    }
}

final class CommandDoubleTapMonitor {
    private let interval: TimeInterval
    private let maximumTapDuration: TimeInterval
    private let onCommandTap: () -> Void
    private let onDoubleTap: () -> Void
    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []
    private var detector: CommandDoubleTapDetector
    private var commandWasDown = false

    init(
        interval: TimeInterval = AppSettings.commandDoubleTapInterval,
        maximumTapDuration: TimeInterval = AppSettings.commandTapMaximumDuration,
        onCommandTap: @escaping () -> Void = {},
        onDoubleTap: @escaping () -> Void
    ) {
        self.interval = interval
        self.maximumTapDuration = maximumTapDuration
        self.onCommandTap = onCommandTap
        self.onDoubleTap = onDoubleTap
        self.detector = CommandDoubleTapDetector(interval: interval, maximumTapDuration: maximumTapDuration)
    }

    func start() {
        _ = AXIsProcessTrusted()

        let interruptingEvents: NSEvent.EventTypeMask = [
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handle(event)
        }) {
            globalMonitors.append(monitor)
        }

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: interruptingEvents, handler: { [weak self] _ in
            self?.interruptCommandSequence()
        }) {
            globalMonitors.append(monitor)
        }

        if let localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            localMonitors.append(localFlagsMonitor)
        }

        if let localInterruptMonitor = NSEvent.addLocalMonitorForEvents(matching: interruptingEvents, handler: { [weak self] event in
            self?.interruptCommandSequence()
            return event
        }) {
            localMonitors.append(localInterruptMonitor)
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
        let commandIsDown = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
        defer {
            commandWasDown = commandIsDown
        }

        if commandIsDown && !commandWasDown {
            onCommandTap()
            detector.commandKeyDown(at: event.timestamp)
            return
        }

        if !commandIsDown && commandWasDown, detector.commandKeyUp(at: event.timestamp) {
            onDoubleTap()
        }
    }

    private func interruptCommandSequence() {
        detector.interrupt()
    }
}
