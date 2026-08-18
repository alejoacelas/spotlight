import AppKit
import Carbon

struct AppShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let key: String

    var displayName: String {
        var value = ""
        if carbonModifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        return value + key.uppercased()
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.key = key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keyCode = try container.decode(UInt32.self, forKey: .keyCode)
        let carbonModifiers = try container.decode(UInt32.self, forKey: .carbonModifiers)
        let key = try container.decode(String.self, forKey: .key)
        guard Self.isValid(keyCode: keyCode, carbonModifiers: carbonModifiers, key: key) else {
            throw DecodingError.dataCorruptedError(
                forKey: .keyCode,
                in: container,
                debugDescription: "Invalid persisted application shortcut"
            )
        }
        self.init(keyCode: keyCode, carbonModifiers: carbonModifiers, key: key)
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        guard modifiers & (UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)) != 0,
              let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines),
              let character = characters.first,
              Self.isValid(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers, key: String(character)) else { return nil }
        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers, key: String(character))
    }

    static func isValid(keyCode: UInt32, carbonModifiers: UInt32, key: String) -> Bool {
        let allowed = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let required = UInt32(controlKey | optionKey | cmdKey)
        return keyCode <= 127
            && carbonModifiers & ~allowed == 0
            && carbonModifiers & required != 0
            && key.count == 1
            && key.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }
}

final class ShortcutRecorderView: NSView {
    private let label = NSTextField(labelWithString: "Press a shortcut")
    private(set) var shortcut: AppShortcut?
    var onChange: ((AppShortcut?) -> Void)?

    init(shortcut: AppShortcut?) {
        self.shortcut = shortcut
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 42))
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        updateLabel()
    }

    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        return true
    }

    override func resignFirstResponder() -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        return true
    }

    override func keyDown(with event: NSEvent) {
        if [36, 53, 76].contains(event.keyCode) { super.keyDown(with: event); return }
        record(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if [36, 53, 76].contains(event.keyCode) { return false }
        record(event)
        return true
    }

    private func record(_ event: NSEvent) {
        guard let shortcut = AppShortcut(event: event) else {
            NSSound.beep()
            label.stringValue = "Include ⌃, ⌥, or ⌘"
            return
        }
        self.shortcut = shortcut
        updateLabel()
        onChange?(shortcut)
    }

    private func updateLabel() {
        label.stringValue = shortcut?.displayName ?? "Press a shortcut"
    }
}
