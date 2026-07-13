import AppKit

enum ApplicationCatalog {
    private static let ownBundleIdentifier = "com.alejoacelas.launcher"

    static func load() -> [ApplicationRecord] {
        let fileManager = FileManager.default
        let roots = applicationRoots().filter { fileManager.fileExists(atPath: $0.path) }
        var seenPaths = Set<String>()
        var applications: [ApplicationRecord] = []

        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isPackageKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else { continue }
                enumerator.skipDescendants()
                let path = url.standardizedFileURL.path
                guard seenPaths.insert(path).inserted else { continue }
                let application = record(for: url)
                if application.bundleIdentifier != ownBundleIdentifier { applications.append(application) }
            }
        }

        return applications.sorted {
            if $0.name.localizedCaseInsensitiveCompare($1.name) != .orderedSame {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.url.path < $1.url.path
        }
    }

    private static func applicationRoots() -> [URL] {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationDirectory, [.userDomainMask, .localDomainMask, .systemDomainMask], true)
        return Array(Set(paths.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }))
    }

    private static func record(for url: URL) -> ApplicationRecord {
        let bundle = Bundle(url: url)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let filename = url.deletingPathExtension().lastPathComponent
        let name = [displayName, bundleName, filename].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? filename
        let lastUsedAt = NSMetadataItem(url: url)?.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
        return ApplicationRecord(name: name, url: url, bundleIdentifier: bundle?.bundleIdentifier, lastUsedAt: lastUsedAt)
    }
}
