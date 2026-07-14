import Foundation
import Carbon
import Testing
@testable import Launcher

private func app(_ name: String, path: String? = nil, lastUsedAt: Date? = nil) -> ApplicationRecord {
    ApplicationRecord(name: name, url: URL(fileURLWithPath: path ?? "/Applications/\(name).app"), bundleIdentifier: nil, lastUsedAt: lastUsedAt)
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

@Test func autoLaunchNeedsTwoCharactersAndOneResult() {
    let safari = app("Safari")
    let oneResult = LauncherModel.matches(query: "saf", applications: [safari, app("Mail")])
    #expect(LauncherModel.uniqueMatch(query: "s", matches: oneResult) == nil)
    #expect(LauncherModel.uniqueMatch(query: "saf", matches: oneResult)?.name == "Safari")
    let twoResults = LauncherModel.matches(query: "cal", applications: [app("Calendar"), app("Calculator")])
    #expect(LauncherModel.uniqueMatch(query: "cal", matches: twoResults) == nil)
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

@Test func aliasesChangeSearchNameWithoutLosingOriginalName() {
    let safari = app("Safari")
    let aliases = [ApplicationAliases.key(for: safari): "Web"]
    let renamed = ApplicationAliases.applying(aliases, to: safari)
    #expect(renamed.name == "Web")
    #expect(renamed.originalName == "Safari")
    #expect(LauncherModel.matches(query: "web", applications: [renamed]).count == 1)
    #expect(LauncherModel.matches(query: "safari", applications: [renamed]).count == 1)
    #expect(ApplicationAliases.applying([:], to: renamed).name == "Safari")
}

@Test func appShortcutsDisplayAndPersist() throws {
    let shortcut = AppShortcut(keyCode: 0, carbonModifiers: UInt32(optionKey | cmdKey), key: "a")
    #expect(shortcut.displayName == "⌥⌘A")
    let data = try JSONEncoder().encode(["app": shortcut])
    #expect(try JSONDecoder().decode([String: AppShortcut].self, from: data) == ["app": shortcut])
}
