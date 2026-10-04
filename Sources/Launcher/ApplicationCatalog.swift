import AppKit

struct ApplicationCatalogResult: Sendable {
    let applications: [ApplicationRecord]
    let failures: [String]

    var isComplete: Bool { failures.isEmpty }
}

enum ApplicationCatalog {
    private static let ownBundleIdentifier = "com.alejoacelas.launcher"

    static func load() -> ApplicationCatalogResult {
        load(roots: applicationRoots(), fixedURLs: fixedApplicationURLs())
    }

    static func load(
        roots: [URL],
        fixedURLs: [URL] = [],
        fileManager: FileManager = .default
    ) -> ApplicationCatalogResult {
        var seenPaths = Set<String>()
        var applications: [ApplicationRecord] = []
        var failures: [String] = []

        func appendApplication(at sourceURL: URL) {
            do {
                let url = try resolvedApplicationURL(sourceURL, fileManager: fileManager)
                let path = url.standardizedFileURL.path
                guard seenPaths.insert(path).inserted else { return }
                let application = record(for: url)
                if application.bundleIdentifier != ownBundleIdentifier {
                    applications.append(application)
                }
            } catch {
                // Broken aliases and symlinks are common after uninstalling an app.
                // Skip only that entry; the rest of the catalog remains trustworthy.
            }
        }

        for url in fixedURLs where fileManager.fileExists(atPath: url.path) {
            appendApplication(at: url)
        }

        for root in roots where fileManager.fileExists(atPath: root.path) {
            var rootFailures: [String] = []
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isAliasFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { url, error in
                    rootFailures.append("\(url.path): \(error.localizedDescription)")
                    return true
                }
            ) else {
                failures.append("Could not read \(root.path)")
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else { continue }
                enumerator.skipDescendants()
                appendApplication(at: url)
            }
            failures.append(contentsOf: rootFailures)
        }

        let sorted = deduplicated(applications).sorted {
            if $0.name.localizedCaseInsensitiveCompare($1.name) != .orderedSame {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.url.path < $1.url.path
        }
        return ApplicationCatalogResult(applications: sorted, failures: failures)
    }

    static func preservingLastGoodCatalog(
        _ previous: [ApplicationRecord],
        after result: ApplicationCatalogResult
    ) -> [ApplicationRecord] {
        if !previous.isEmpty, !result.isComplete { return previous }
        return result.applications
    }

    static func deduplicated(_ applications: [ApplicationRecord]) -> [ApplicationRecord] {
        var unique: [String: ApplicationRecord] = [:]
        for application in applications {
            let identity = application.bundleIdentifier?.lowercased() ?? "path:\(application.url.standardizedFileURL.path)"
            guard let existing = unique[identity] else {
                unique[identity] = application
                continue
            }
            if isPreferred(application, over: existing) { unique[identity] = application }
        }
        return Array(unique.values)
    }

    static func applicationRoots() -> [URL] {
        let paths = NSSearchPathForDirectoriesInDomains(
            .applicationDirectory,
            [.userDomainMask, .localDomainMask, .systemDomainMask],
            true
        )
        return Array(Set(paths.map {
            URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
        })).sorted { $0.path < $1.path }
    }

    private static func fixedApplicationURLs() -> [URL] {
        [URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app", isDirectory: true)]
    }

    private static func resolvedApplicationURL(_ url: URL, fileManager: FileManager) throws -> URL {
        var resolved = url
        let values = try url.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey])
        if values.isAliasFile == true {
            resolved = try URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting])
        }
        if values.isSymbolicLink == true {
            resolved = resolved.resolvingSymlinksInPath()
        }
        resolved = resolved.standardizedFileURL
        guard fileManager.fileExists(atPath: resolved.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return resolved
    }

    private static func isPreferred(_ candidate: ApplicationRecord, over existing: ApplicationRecord) -> Bool {
        switch (candidate.bundleVersion, existing.bundleVersion) {
        case let (candidateVersion?, existingVersion?):
            let order = candidateVersion.compare(existingVersion, options: [.numeric, .caseInsensitive])
            if order != .orderedSame { return order == .orderedDescending }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        return candidate.url.standardizedFileURL.path < existing.url.standardizedFileURL.path
    }

    private static func record(for url: URL) -> ApplicationRecord {
        let bundle = Bundle(url: url)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let bundleVersion = bundle?.object(forInfoDictionaryKey: "CFBundleVersion").map { String(describing: $0) }
        let filename = url.deletingPathExtension().lastPathComponent
        let name = [displayName, bundleName, filename]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? filename
        let lastUsedAt = NSMetadataItem(url: url)?.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
        return ApplicationRecord(
            name: name,
            url: url,
            bundleIdentifier: bundle?.bundleIdentifier,
            bundleVersion: bundleVersion,
            lastUsedAt: lastUsedAt
        )
    }
}
