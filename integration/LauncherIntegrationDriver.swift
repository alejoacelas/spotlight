import AppKit
import ApplicationServices

enum SmokeError: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case let .failed(message): return message }
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw SmokeError.failed(message) }
}

func wait(_ description: String, timeout: TimeInterval = 2, for condition: () -> Bool) throws {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while Date() < deadline {
        if condition() { return }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
    }
    throw SmokeError.failed("Timed out waiting for \(description)")
}

func attribute(_ name: CFString, of element: AXUIElement) -> AnyObject? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
    return value
}

func stringAttribute(_ name: CFString, of element: AXUIElement) -> String? {
    attribute(name, of: element) as? String
}

func descendants(of root: AXUIElement) -> [AXUIElement] {
    var result: [AXUIElement] = []
    var pending = [root]
    while let element = pending.popLast() {
        result.append(element)
        if let children = attribute(kAXChildrenAttribute as CFString, of: element) as? [AXUIElement] {
            pending.append(contentsOf: children)
        }
        if let windows = attribute(kAXWindowsAttribute as CFString, of: element) as? [AXUIElement] {
            pending.append(contentsOf: windows)
        }
    }
    return result
}

func element(identifier: String, in app: AXUIElement) -> AXUIElement? {
    descendants(of: app).first {
        stringAttribute(kAXIdentifierAttribute as CFString, of: $0) == identifier
    }
}

func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) throws {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
        throw SmokeError.failed("Could not create key event")
    }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

func type(_ text: String) throws {
    for character in text {
        let units = Array(String(character).utf16)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw SmokeError.failed("Could not create text event")
        }
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

func logLines(at path: String) -> [String] {
    (try? String(contentsOfFile: path, encoding: .utf8))?
        .split(separator: "\n").map(String.init) ?? []
}

func showLauncher(_ app: AXUIElement, previousBundleIdentifier: String?) throws {
    try postKey(49, flags: .maskCommand)
    try wait("focused Launcher search field") {
        guard let search = element(identifier: "launcher.search", in: app) else { return false }
        return (attribute(kAXFocusedAttribute as CFString, of: search) as? Bool) == true
    }
    try require(
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == previousBundleIdentifier,
        "Showing Launcher changed the frontmost application"
    )
}

func hideLauncher(_ app: AXUIElement, previousBundleIdentifier: String?) throws {
    try postKey(53)
    try wait("Launcher dismissal") { element(identifier: "launcher.search", in: app) == nil }
    try require(
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == previousBundleIdentifier,
        "Dismissing Launcher changed the frontmost application"
    )
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw SmokeError.failed("Usage: LauncherIntegrationDriver LAUNCHER_EXECUTABLE OUTPUT_LOG")
    }
    let trustOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    guard AXIsProcessTrustedWithOptions(trustOptions) else {
        fputs("Accessibility permission is required for the signed integration driver.\n", stderr)
        exit(77)
    }

    let executable = CommandLine.arguments[1]
    let output = CommandLine.arguments[2]
    try? FileManager.default.removeItem(atPath: output)
    let previousBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = ["--integration-test-output=\(output)"]
    try process.run()
    defer {
        process.terminate()
        process.waitUntilExit()
    }
    let app = AXUIElementCreateApplication(process.processIdentifier)
    try wait("Launcher startup") { process.isRunning }

    try showLauncher(app, previousBundleIdentifier: previousBundleIdentifier)
    try type("test")
    try wait("named results table") { element(identifier: "launcher.results", in: app) != nil }
    let results = try { () -> AXUIElement in
        guard let value = element(identifier: "launcher.results", in: app) else {
            throw SmokeError.failed("The named results table was missing")
        }
        return value
    }()
    let beforeDown = attribute(kAXSelectedRowsAttribute as CFString, of: results) as? [AXUIElement]
    try postKey(125)
    try wait("Down Arrow selection") {
        let after = attribute(kAXSelectedRowsAttribute as CFString, of: results) as? [AXUIElement]
        return beforeDown?.first != after?.first
    }
    try hideLauncher(app, previousBundleIdentifier: previousBundleIdentifier)

    for index in 1...6 {
        try showLauncher(app, previousBundleIdentifier: previousBundleIdentifier)
        try type("test")
        try postKey(CGKeyCode(17 + index), flags: .maskCommand)
        try wait("Command-\(index) launch") { logLines(at: output).count == index }
        try require(logLines(at: output).last == "Test App \(index)", "Command-\(index) opened the wrong row")
    }

    try showLauncher(app, previousBundleIdentifier: previousBundleIdentifier)
    try type("test")
    try postKey(36)
    try wait("Return launch") { logLines(at: output).count == 7 }
    try require(logLines(at: output).last == "Test App 1", "Return opened the wrong row")

    try showLauncher(app, previousBundleIdentifier: previousBundleIdentifier)
    try type("test")
    try postKey(40, flags: .maskCommand)
    try wait("Command-K action sheet") {
        descendants(of: app).contains {
            stringAttribute(kAXRoleAttribute as CFString, of: $0) == (kAXSheetRole as String)
        }
    }
    try postKey(53)

    print("Signed launcher integration smoke test passed")
} catch {
    fputs("Launcher integration smoke test failed: \(error)\n", stderr)
    exit(1)
}
