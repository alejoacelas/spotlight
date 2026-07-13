import Foundation
import Testing
@testable import Launcher

private func app(_ name: String, path: String? = nil) -> ApplicationRecord {
    ApplicationRecord(name: name, url: URL(fileURLWithPath: path ?? "/Applications/\(name).app"), bundleIdentifier: nil)
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

@Test func exactMatchNeedsTwoCharactersAndMustBeUnique() {
    #expect(LauncherModel.uniqueExactMatch(query: "X", applications: [app("X")]) == nil)
    #expect(LauncherModel.uniqueExactMatch(query: "Safari", applications: [app("Safari")])?.name == "Safari")
    #expect(LauncherModel.uniqueExactMatch(query: "Safari", applications: [app("Safari", path: "/Applications/Safari.app"), app("Safari", path: "/Other/Safari.app")]) == nil)
}

@Test func unmatchedQueriesReturnNoResults() {
    #expect(LauncherModel.matches(query: "zzzzzz", applications: [app("Safari"), app("Mail")]).isEmpty)
}

@Test func resultCountIsLimited() {
    let applications = (0..<20).map { app("App \($0)") }
    #expect(LauncherModel.matches(query: "", applications: applications).count == LauncherModel.resultLimit)
}
