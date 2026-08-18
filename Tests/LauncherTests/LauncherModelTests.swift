import Foundation
import Carbon
import AppKit
import Testing
@testable import Launcher

@Test @MainActor func launcherPanelDoesNotActivateTheApplication() {
    let controller = LauncherWindowController()
    let panel = controller.window as? LauncherPanel
    #expect(panel != nil)
    #expect(panel?.styleMask.contains(.nonactivatingPanel) == true)
    #expect(panel?.canBecomeKey == true)
    #expect(panel?.canBecomeMain == false)
}

@Test @MainActor func launcherPanelRoutesEveryDocumentedCommand() throws {
    let controller = LauncherWindowController()
    let panel = try #require(controller.window as? LauncherPanel)
    controller.setApplications((1...6).map { app("Test App \($0)") })
    var launched: [String] = []
    var renamed = false
    var actions = false
    controller.onLaunch = { launched.append($0.name) }
    panel.renameAction = { renamed = true }
    panel.actionsAction = { actions = true }

    func command(_ characters: String, keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )!
    }

    for index in 1...6 {
        #expect(panel.performKeyEquivalent(with: command("\(index)", keyCode: UInt16(17 + index))))
    }
    #expect(launched == (1...6).map { "Test App \($0)" })
    #expect(panel.performKeyEquivalent(with: command("r", keyCode: 15)))
    #expect(panel.performKeyEquivalent(with: command("k", keyCode: 40)))
    #expect(renamed)
    #expect(actions)
}

private func app(_ name: String, path: String? = nil, bundleIdentifier: String? = nil, bundleVersion: String? = nil, lastUsedAt: Date? = nil) -> ApplicationRecord {
    ApplicationRecord(name: name, url: URL(fileURLWithPath: path ?? "/Applications/\(name).app"), bundleIdentifier: bundleIdentifier, bundleVersion: bundleVersion, lastUsedAt: lastUsedAt)
}

@Test func ranksExactPrefixLaterAndSubsequenceMatches() {
    let applications = [app("Calendar"), app("Google Chrome"), app("Visual Studio Code"), app("Calculator")]
    #expect(LauncherModel.matches(query: "calendar", applications: applications).first?.application.name == "Calendar")
    #expect(LauncherModel.matches(query: "calc", applications: applications).first?.application.name == "Calculator")
    #expect(LauncherModel.matches(query: "chrome", applications: applications).first?.application.name == "Google Chrome")
    #expect(LauncherModel.matches(query: "vsc", applications: applications).first?.application.name == "Visual Studio Code")
}

@Test func toleratesTyposAndDiacritics() {
    let applications = [app("Slack"), app("Safari"), app("Café")]
    #expect(LauncherModel.matches(query: "slak", applications: applications).first?.application.name == "Slack")
    #expect(LauncherModel.matches(query: "safri", applications: applications).first?.application.name == "Safari")
    #expect(LauncherModel.matches(query: "cafe", applications: applications).first?.application.name == "Café")
}

@Test func autoLaunchUsesAUniqueResultOrDecisiveThreeCharacterPrefix() {
    let safari = app("Safari")
    let oneResult = LauncherModel.matches(query: "saf", applications: [safari, app("Mail")])
    #expect(LauncherModel.uniqueMatch(query: "s", matches: oneResult) == nil)
    #expect(LauncherModel.uniqueMatch(query: "saf", matches: oneResult)?.name == "Safari")
    let twoResults = LauncherModel.matches(query: "cal", applications: [app("Calendar"), app("Calculator")])
    #expect(LauncherModel.uniqueMatch(query: "cal", matches: twoResults) == nil)

    let claude = app("Claude")
    let weakerMatches = LauncherModel.matches(query: "clau", applications: [claude, app("Calendar Utility")])
    #expect(weakerMatches.count > 1)
    #expect(LauncherModel.uniqueMatch(query: "clau", matches: weakerMatches) == claude)
}

@Test func typoMatchingStartsAtFourCharacters() {
    let applications = [app("Claude")]
    #expect(LauncherModel.matches(query: "clu", applications: applications).isEmpty)
    #expect(LauncherModel.matches(query: "cluude", applications: applications).first?.application.name == "Claude")
}

@Test func equalQualityMatchesRankByMostRecentUse() {
    let old = app("Beta", lastUsedAt: Date(timeIntervalSince1970: 10))
    let recent = app("Alpha", lastUsedAt: Date(timeIntervalSince1970: 20))
    #expect(LauncherModel.matches(query: "", applications: [old, recent]).map(\.application.name) == ["Alpha", "Beta"])
}

@Test func unmatchedQueriesReturnNoResults() {
    #expect(LauncherModel.matches(query: "zzzzzz", applications: [app("Safari"), app("Mail")]).isEmpty)
}

@Test func resultCountIsLimited() {
    let applications = (0..<20).map { app("App \($0)") }
    #expect(LauncherModel.matches(query: "", applications: applications).count == LauncherModel.resultLimit)
}

@Test func aliasesReplaceTheSearchNameWithoutLosingTheRestorableOriginalName() {
    let safari = app("Safari")
    let aliases = [ApplicationAliases.key(for: safari): "Web"]
    let renamed = ApplicationAliases.applying(aliases, to: safari)
    #expect(renamed.name == "Web")
    #expect(renamed.originalName == "Safari")
    #expect(LauncherModel.matches(query: "web", applications: [renamed]).count == 1)
    #expect(LauncherModel.matches(query: "safari", applications: [renamed]).count == 1)
    #expect(ApplicationAliases.applying([:], to: renamed).name == "Safari")
}

@Test func rankingFixtureMatchesExpectedOrder() throws {
    struct Fixture: Decodable {
        struct FixtureApplication: Decodable {
            let name: String
            let lastUsedAt: TimeInterval?
        }
        struct FixtureCase: Decodable {
            let query: String
            let expected: [String]
        }
        let applications: [FixtureApplication]
        let cases: [FixtureCase]
    }

    let url = try #require(Bundle.module.url(forResource: "ranking", withExtension: "json"))
    let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    let applications = fixture.applications.map {
        app(
            $0.name,
            lastUsedAt: $0.lastUsedAt.map(Date.init(timeIntervalSince1970:))
        )
    }

    for testCase in fixture.cases {
        let names = LauncherModel.matches(query: testCase.query, applications: applications)
            .map(\.application.name)
        #expect(Array(names.prefix(testCase.expected.count)) == testCase.expected, "Query: \(testCase.query)")
    }
}

@Test func rankingStaysWithinTheTypingBudget() {
    let applications = (0..<500).map { app("Application \(String(format: "%03d", $0))") }
    var durations: [UInt64] = []
    for _ in 0..<200 {
        let started = DispatchTime.now().uptimeNanoseconds
        _ = LauncherModel.matches(query: "app", applications: applications)
        durations.append(DispatchTime.now().uptimeNanoseconds - started)
    }
    durations.sort()
    let p95Milliseconds = Double(durations[Int(Double(durations.count) * 0.95)]) / 1_000_000
    #expect(p95Milliseconds < 16, "p95 was \(p95Milliseconds) ms")
}

@Test @MainActor func autoLaunchWaitsAndCancelsWhenTypingContinues() async throws {
    let controller = LauncherWindowController()
    controller.setApplications([app("Safari"), app("Calendar"), app("Calculator")])
    var launched: [String] = []
    controller.onLaunch = { launched.append($0.name) }

    controller.setDemoQuery("saf")
    controller.setDemoQuery("cal")
    try await Task.sleep(for: .milliseconds(150))

    #expect(launched.isEmpty)
}

@Test @MainActor func autoLaunchOpensStableUniqueMatchAfterDelay() async throws {
    let controller = LauncherWindowController()
    controller.setApplications([app("Safari"), app("Mail")])
    var launched: [String] = []
    controller.onLaunch = { launched.append($0.name) }

    controller.setDemoQuery("saf")
    #expect(launched.isEmpty)
    try await Task.sleep(for: .milliseconds(150))

    #expect(launched == ["Safari"])
}

@Test func bundleIdentifierKeepsAnUpstreamProductNameSearchable() {
    let chatGPT = app("ChatGPT", bundleIdentifier: "com.openai.codex")
    let matches = LauncherModel.matches(query: "codex", applications: [chatGPT])
    #expect(matches.first?.application == chatGPT)
    #expect(LauncherModel.uniqueMatch(query: "codex", matches: matches) == chatGPT)
}

@Test func excludedApplicationsDoNotReachLauncherResults() {
    let safari = app("Safari")
    let mail = app("Mail")
    let visible = ApplicationExclusions.applying([ApplicationAliases.key(for: safari)], to: [safari, mail])
    #expect(visible == [mail])
    #expect(LauncherModel.matches(query: "safari", applications: visible).isEmpty)
}

@Test func duplicateBundleIdentifiersKeepOnlyTheNewestInstalledVersion() {
    let old = app("ChatGPT", path: "/Applications/ChatGPT.app", bundleIdentifier: "com.openai.codex", bundleVersion: "5440")
    let new = app("ChatGPT", path: "/Applications/Codex.app", bundleIdentifier: "com.openai.codex", bundleVersion: "5551")
    #expect(ApplicationCatalog.deduplicated([old, new]) == [new])
    #expect(ApplicationCatalog.deduplicated([new, old]) == [new])
}

@Test func appShortcutsDisplayAndPersist() throws {
    let shortcut = AppShortcut(keyCode: 0, carbonModifiers: UInt32(optionKey | cmdKey), key: "a")
    #expect(shortcut.displayName == "⌥⌘A")
    let data = try JSONEncoder().encode(["app": shortcut])
    #expect(try JSONDecoder().decode([String: AppShortcut].self, from: data) == ["app": shortcut])
}
