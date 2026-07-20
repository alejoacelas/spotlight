import Carbon

enum SpotlightShortcut: String, CaseIterable {
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

final class GlobalHotKey {
    private static var nextIdentifier: UInt32 = 1
    private static let signature = "Lnch".utf8.reduce(0) { ($0 << 8) + OSType($1) }

    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void
    private let identifier: EventHotKeyID

    init(action: @escaping () -> Void) {
        self.action = action
        identifier = EventHotKeyID(signature: Self.signature, id: Self.nextIdentifier)
        Self.nextIdentifier += 1
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return noErr }
            let owner = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            var received = EventHotKeyID()
            var size = MemoryLayout<EventHotKeyID>.size
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, size, &size, &received)
            guard status == noErr, received.signature == owner.identifier.signature, received.id == owner.identifier.id else {
                return OSStatus(eventNotHandledErr)
            }
            owner.action()
            return noErr
        }, 1, &eventType, pointer, &eventHandler)
    }

    deinit {
        unregister()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    @discardableResult
    func register(_ shortcut: SpotlightShortcut) -> Bool {
        register(keyCode: UInt32(kVK_Space), carbonModifiers: shortcut.carbonModifiers)
    }

    @discardableResult
    func register(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        unregister()
        let status = RegisterEventHotKey(keyCode, carbonModifiers, identifier, GetApplicationEventTarget(), 0, &eventHotKey)
        return status == noErr
    }

    func unregister() {
        if let eventHotKey { UnregisterEventHotKey(eventHotKey) }
        eventHotKey = nil
    }
}
