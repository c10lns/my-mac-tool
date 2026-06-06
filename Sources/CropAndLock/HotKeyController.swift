import Carbon
import Foundation

enum HotKeyControllerError: Error {
    case installHandlerFailed(OSStatus)
    case registerHotKeyFailed(OSStatus)
}

final class HotKeyController {
    private let onTrigger: () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func register() throws {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }

                let controller = Unmanaged<HotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                controller.onTrigger()
                return noErr
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )

        guard handlerStatus == noErr else {
            throw HotKeyControllerError.installHandlerFailed(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature("CRLK"), id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            UInt32(cmdKey | controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )

        guard hotKeyStatus == noErr else {
            throw HotKeyControllerError.registerHotKeyFailed(hotKeyStatus)
        }
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private static func signature(_ value: String) -> OSType {
        value.utf8.reduce(0) { result, byte in
            (result << 8) + OSType(byte)
        }
    }
}
