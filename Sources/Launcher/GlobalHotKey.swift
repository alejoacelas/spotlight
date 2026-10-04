import Carbon

enum LauncherShortcut: String, CaseIterable {
    case commandSpace
    case optionSpace

    var title: String {
        switch self {
        case .commandSpace: return "Command-Space"
        case .optionSpace: return "Option-Space"
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .commandSpace: return UInt32(cmdKey)
        case .optionSpace: return UInt32(optionKey)
        }
    }
}

enum GlobalHotKeyError: LocalizedError {
    case eventHandlerInstallationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .eventHandlerInstallationFailed(status):
            return "The global shortcut listener could not start (Carbon error \(status))."
        }
    }
}

final class GlobalHotKey {
    private static var nextIdentifier: UInt32 = 1
    private static let signature = "Lnch".utf8.reduce(0) { ($0 << 8) + OSType($1) }

    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var registeredIdentifier: EventHotKeyID?
    private let action: () -> Void
    private(set) var registeredKeyCode: UInt32?
    private(set) var registeredCarbonModifiers: UInt32?

    init(action: @escaping () -> Void) throws {
        self.action = action
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            var received = EventHotKeyID()
            var size = MemoryLayout<EventHotKeyID>.size
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                size,
                &size,
                &received
            )
            guard status == noErr,
                  let registered = owner.registeredIdentifier,
                  received.signature == registered.signature,
                  received.id == registered.id else {
                return OSStatus(eventNotHandledErr)
            }
            owner.action()
            return noErr
        }, 1, &eventType, pointer, &eventHandler)
        guard status == noErr else {
            throw GlobalHotKeyError.eventHandlerInstallationFailed(status)
        }
    }

    deinit {
        unregister()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    @discardableResult
    func register(_ shortcut: LauncherShortcut) -> Bool {
        register(keyCode: UInt32(kVK_Space), carbonModifiers: shortcut.carbonModifiers)
    }

    @discardableResult
    func register(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        if registeredKeyCode == keyCode, registeredCarbonModifiers == carbonModifiers {
            return true
        }

        let candidateIdentifier = Self.makeIdentifier()
        var candidate: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            candidateIdentifier,
            GetApplicationEventTarget(),
            0,
            &candidate
        )
        guard status == noErr, let candidate else {
            if let candidate { UnregisterEventHotKey(candidate) }
            return false
        }

        let previous = eventHotKey
        eventHotKey = candidate
        registeredIdentifier = candidateIdentifier
        registeredKeyCode = keyCode
        registeredCarbonModifiers = carbonModifiers
        if let previous { UnregisterEventHotKey(previous) }
        return true
    }

    func unregister() {
        if let eventHotKey { UnregisterEventHotKey(eventHotKey) }
        eventHotKey = nil
        registeredIdentifier = nil
        registeredKeyCode = nil
        registeredCarbonModifiers = nil
    }

    private static func makeIdentifier() -> EventHotKeyID {
        defer { nextIdentifier &+= 1 }
        return EventHotKeyID(signature: signature, id: nextIdentifier)
    }
}
