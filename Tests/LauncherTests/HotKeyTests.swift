import Carbon
import Foundation
import Testing
@testable import Launcher

@Test @MainActor func failedReplacementKeepsTheWorkingGlobalShortcut() throws {
    let modifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)
    let owner = try GlobalHotKey {}
    let blocker = try GlobalHotKey {}

    #expect(owner.register(keyCode: UInt32(kVK_F17), carbonModifiers: modifiers))
    #expect(blocker.register(keyCode: UInt32(kVK_F18), carbonModifiers: modifiers))
    #expect(!owner.register(keyCode: UInt32(kVK_F18), carbonModifiers: modifiers))
    #expect(owner.registeredKeyCode == UInt32(kVK_F17))
    #expect(owner.registeredCarbonModifiers == modifiers)
}

@Test func corruptPersistedShortcutsAreRemoved() throws {
    let suite = "LauncherTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data(#"{"app":{"keyCode":999,"carbonModifiers":256,"key":"A"}}"#.utf8), forKey: "applicationShortcuts")

    let loaded = LauncherPreferences.loadAppShortcuts(from: defaults)

    #expect(loaded.shortcuts.isEmpty)
    #expect(loaded.resetCorruptValue)
    #expect(defaults.data(forKey: "applicationShortcuts") == nil)
}

@Test func validPersistedShortcutsRoundTrip() throws {
    let suite = "LauncherTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let shortcut = AppShortcut(keyCode: 0, carbonModifiers: UInt32(optionKey | cmdKey), key: "a")

    LauncherPreferences.saveAppShortcuts(["app": shortcut], to: defaults)
    let loaded = LauncherPreferences.loadAppShortcuts(from: defaults)

    #expect(loaded.shortcuts == ["app": shortcut])
    #expect(!loaded.resetCorruptValue)
}

@Test func recentUsePersistsByStableApplicationKey() throws {
    let suite = "LauncherTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    LauncherPreferences.saveRecentUse(["com.example.app": 123], to: defaults)

    #expect(LauncherPreferences.loadRecentUse(from: defaults) == ["com.example.app": 123])
}

@Test func metricsStoreCountsWithoutQueryText() throws {
    let suite = "LauncherTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let metrics = LauncherMetrics(defaults: defaults)

    for _ in 0..<25 { metrics.recordSearch(seconds: 0.001) }
    metrics.recordSelection(applicationKey: "com.example.app")

    #expect(defaults.integer(forKey: "metricSearchCount") == 25)
    #expect(defaults.dictionary(forKey: "metricSelections") as? [String: Int] == ["com.example.app": 1])
    #expect(defaults.dictionaryRepresentation().keys.allSatisfy { !$0.lowercased().contains("query") })
}
