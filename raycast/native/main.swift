import AppKit

struct CatalogEntry: Encodable {
    let name: String
    let path: String
    let bundleId: String?
    let lastUsedAt: Double?
}
struct Snapshot: Encodable {
    let applications: [CatalogEntry]
    let failures: [String]
    let aliases: [String: String]
    let hidden: [String]
    let recent: [String: Double]
}

// Window ordering works without reading screen contents or requesting screen recording.
func launcherIsInFront() -> Bool {
    let flags = CGEventSource.flagsState(.combinedSessionState)
    if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty { return false }
    guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
    for window in windows {
        guard let layer = window[kCGWindowLayer as String] as? Int, layer >= 0, layer < 25,
              let bounds = window[kCGWindowBounds as String] as? [String: Double],
              (bounds["Width"] ?? 0) > 100, (bounds["Height"] ?? 0) > 60,
              let pid = window[kCGWindowOwnerPID as String] as? Int32 else { continue }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.raycast.macos"
    }
    return false
}

if CommandLine.arguments.contains("frontmost-server") {
    while let line = readLine() {
        guard let id = Int(line) else { continue }
        let reply = "{\"id\":\(id),\"front\":\(launcherIsInFront())}\n"
        FileHandle.standardOutput.write(Data(reply.utf8))
    }
} else if CommandLine.arguments.contains("frontmost") {
    print(launcherIsInFront() ? "true" : "false")
} else {
    let defaults = UserDefaults(suiteName: "com.alejoacelas.launcher")!
    let catalog = ApplicationCatalog.load()
    let snapshot = Snapshot(
        applications: catalog.applications.map { CatalogEntry(name: $0.name, path: $0.url.path, bundleId: $0.bundleIdentifier, lastUsedAt: $0.lastUsedAt?.timeIntervalSince1970) },
        failures: catalog.failures,
        aliases: defaults.dictionary(forKey: "applicationAliases") as? [String: String] ?? [:],
        hidden: defaults.stringArray(forKey: "excludedApplications") ?? [],
        recent: (defaults.dictionary(forKey: "applicationLastUsedAt") ?? [:]).compactMapValues { ($0 as? NSNumber)?.doubleValue }
    )
    FileHandle.standardOutput.write(try JSONEncoder().encode(snapshot))
}
