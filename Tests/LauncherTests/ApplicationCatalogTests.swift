import Foundation
import Testing
@testable import Launcher

private func makeApplication(
    named name: String,
    bundleIdentifier: String,
    version: String = "1",
    under root: URL
) throws -> URL {
    let application = root.appendingPathComponent("\(name).app", isDirectory: true)
    let contents = application.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist: [String: Any] = [
        "CFBundleDisplayName": name,
        "CFBundleIdentifier": bundleIdentifier,
        "CFBundleVersion": version,
        "CFBundlePackageType": "APPL",
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: contents.appendingPathComponent("Info.plist"))
    return application
}

@Test func catalogFindsFixedNestedAndSymlinkedApplications() throws {
    let temporary = try TemporaryDirectory()
    let root = temporary.url.appendingPathComponent("Applications", isDirectory: true)
    let nested = root.appendingPathComponent("Utilities", isDirectory: true)
    let external = temporary.url.appendingPathComponent("External", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
    _ = try makeApplication(named: "Nested", bundleIdentifier: "test.nested", under: nested)
    let linkedTarget = try makeApplication(named: "Linked", bundleIdentifier: "test.linked", under: external)
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("Linked.app"),
        withDestinationURL: linkedTarget
    )
    let fixed = try makeApplication(named: "Fixed", bundleIdentifier: "test.fixed", under: external)

    let result = ApplicationCatalog.load(roots: [root], fixedURLs: [fixed])

    #expect(result.isComplete)
    #expect(result.applications.map(\.name) == ["Fixed", "Linked", "Nested"])
    #expect(result.applications.first(where: { $0.name == "Linked" })?.url == linkedTarget.standardizedFileURL)
}

@Test func brokenApplicationSymlinkDoesNotInvalidateCatalog() throws {
    let temporary = try TemporaryDirectory()
    let root = temporary.url.appendingPathComponent("Applications", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    _ = try makeApplication(named: "Healthy", bundleIdentifier: "test.healthy", under: root)
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("Missing.app"),
        withDestinationURL: root.appendingPathComponent("Gone.app")
    )

    let result = ApplicationCatalog.load(roots: [root])

    #expect(result.isComplete)
    #expect(result.applications.map(\.name) == ["Healthy"])
}

@Test func incompleteRefreshPreservesLastGoodCatalog() {
    let previous = [ApplicationRecord(
        name: "Existing",
        url: URL(fileURLWithPath: "/Applications/Existing.app"),
        bundleIdentifier: "test.existing"
    )]
    let incomplete = ApplicationCatalogResult(applications: [], failures: ["permission denied"])

    #expect(ApplicationCatalog.preservingLastGoodCatalog(previous, after: incomplete) == previous)
    #expect(ApplicationCatalog.preservingLastGoodCatalog([], after: incomplete).isEmpty)
}

@Test func catalogWatcherReportsChangesWithinTwoSeconds() throws {
    let temporary = try TemporaryDirectory()
    let root = temporary.url.appendingPathComponent("Applications", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let changed = DispatchSemaphore(value: 0)
    let watcher = ApplicationCatalogWatcher(roots: [root]) { changed.signal() }
    #expect(watcher.start())
    let started = Date()

    _ = try makeApplication(named: "Arrived", bundleIdentifier: "test.arrived", under: root)

    #expect(changed.wait(timeout: .now() + 3) == .success)
    #expect(Date().timeIntervalSince(started) < 2)
    watcher.stop()
}

private final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("launcher-catalog-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
