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

final class GlobalHotKey {
    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return noErr }
            let owner = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            owner.action()
            return noErr
        }, 1, &eventType, pointer, &eventHandler)
    }

    deinit {
        unregister()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    @discardableResult
    func register(_ shortcut: LauncherShortcut) -> Bool {
        unregister()
        let identifier = EventHotKeyID(signature: fourCharacterCode("Lnch"), id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_Space), shortcut.carbonModifiers, identifier, GetApplicationEventTarget(), 0, &eventHotKey)
        return status == noErr
    }

    private func unregister() {
        if let eventHotKey { UnregisterEventHotKey(eventHotKey) }
        eventHotKey = nil
    }

    private func fourCharacterCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
