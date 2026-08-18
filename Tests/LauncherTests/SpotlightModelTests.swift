import Foundation
import Carbon
import Testing
@testable import Launcher

@Test @MainActor func launcherPanelDoesNotActivateTheApplication() {
    let controller = SpotlightWindowController()
    let panel = controller.window as? SpotlightPanel
    #expect(panel != nil)
    #expect(panel?.styleMask.contains(.nonactivatingPanel) == true)
    #expect(panel?.canBecomeKey == true)
    #expect(panel?.canBecomeMain == false)
}

private func app(_ name: String, path: String? = nil, bundleIdentifier: String? = nil, bundleVersion: String? = nil, lastUsedAt: Date? = nil) -> ApplicationRecord {
    ApplicationRecord(name: name, url: URL(fileURLWithPath: path ?? "/Applications/\(name).app"), bundleIdentifier: bundleIdentifier, bundleVersion: bundleVersion, lastUsedAt: lastUsedAt)
}

@Test func ranksExactPrefixLaterAndSubsequenceMatches() {
    let applications = [app("Calendar"), app("Google Chrome"), app("Visual Studio Code"), app("Calculator")]
    #expect(SpotlightModel.matches(query: "calendar", applications: applications).first?.application.name == "Calendar")
    #expect(SpotlightModel.matches(query: "calc", applications: applications).first?.application.name == "Calculator")
    #expect(SpotlightModel.matches(query: "chrome", applications: applications).first?.application.name == "Google Chrome")
    #expect(SpotlightModel.matches(query: "vsc", applications: applications).first?.application.name == "Visual Studio Code")
}

@Test func toleratesTyposAndDiacritics() {
    let applications = [app("Slack"), app("Safari"), app("Café")]
    #expect(SpotlightModel.matches(query: "slak", applications: applications).first?.application.name == "Slack")
    #expect(SpotlightModel.matches(query: "safri", applications: applications).first?.application.name == "Safari")
    #expect(SpotlightModel.matches(query: "cafe", applications: applications).first?.application.name == "Café")
}

@Test func autoLaunchUsesAUniqueResultOrDecisiveThreeCharacterPrefix() {
    let safari = app("Safari")
    let oneResult = SpotlightModel.matches(query: "saf", applications: [safari, app("Mail")])
    #expect(SpotlightModel.uniqueMatch(query: "s", matches: oneResult) == nil)
    #expect(SpotlightModel.uniqueMatch(query: "saf", matches: oneResult)?.name == "Safari")
    let twoResults = SpotlightModel.matches(query: "cal", applications: [app("Calendar"), app("Calculator")])
    #expect(SpotlightModel.uniqueMatch(query: "cal", matches: twoResults) == nil)

    let claude = app("Claude")
    let weakerMatches = SpotlightModel.matches(query: "clau", applications: [claude, app("Calendar Utility")])
    #expect(weakerMatches.count > 1)
    #expect(SpotlightModel.uniqueMatch(query: "clau", matches: weakerMatches) == claude)
}

@Test func typoMatchingStartsAtFourCharacters() {
    let applications = [app("Claude")]
    #expect(SpotlightModel.matches(query: "clu", applications: applications).isEmpty)
    #expect(SpotlightModel.matches(query: "cluude", applications: applications).first?.application.name == "Claude")
}

@Test func equalQualityMatchesRankByMostRecentUse() {
    let old = app("Beta", lastUsedAt: Date(timeIntervalSince1970: 10))
    let recent = app("Alpha", lastUsedAt: Date(timeIntervalSince1970: 20))
    #expect(SpotlightModel.matches(query: "", applications: [old, recent]).map(\.application.name) == ["Alpha", "Beta"])
}

@Test func unmatchedQueriesReturnNoResults() {
    #expect(SpotlightModel.matches(query: "zzzzzz", applications: [app("Safari"), app("Mail")]).isEmpty)
}

@Test func resultCountIsLimited() {
    let applications = (0..<20).map { app("App \($0)") }
    #expect(SpotlightModel.matches(query: "", applications: applications).count == SpotlightModel.resultLimit)
}

@Test func aliasesReplaceTheSearchNameWithoutLosingTheRestorableOriginalName() {
    let safari = app("Safari")
    let aliases = [ApplicationAliases.key(for: safari): "Web"]
    let renamed = ApplicationAliases.applying(aliases, to: safari)
    #expect(renamed.name == "Web")
    #expect(renamed.originalName == "Safari")
    #expect(SpotlightModel.matches(query: "web", applications: [renamed]).count == 1)
    #expect(SpotlightModel.matches(query: "safari", applications: [renamed]).isEmpty)
    #expect(ApplicationAliases.applying([:], to: renamed).name == "Safari")
}

@Test func bundleIdentifierKeepsAnUpstreamProductNameSearchable() {
    let chatGPT = app("ChatGPT", bundleIdentifier: "com.openai.codex")
    let matches = SpotlightModel.matches(query: "codex", applications: [chatGPT])
    #expect(matches.first?.application == chatGPT)
    #expect(SpotlightModel.uniqueMatch(query: "codex", matches: matches) == chatGPT)
}

@Test func excludedApplicationsDoNotReachSpotlightResults() {
    let safari = app("Safari")
    let mail = app("Mail")
    let visible = ApplicationExclusions.applying([ApplicationAliases.key(for: safari)], to: [safari, mail])
    #expect(visible == [mail])
    #expect(SpotlightModel.matches(query: "safari", applications: visible).isEmpty)
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
