import Foundation

struct ApplicationRecord: Hashable, Sendable {
    let name: String
    let originalName: String
    let url: URL
    let bundleIdentifier: String?
    let bundleVersion: String?
    let lastUsedAt: Date?

    init(
        name: String,
        originalName: String? = nil,
        url: URL,
        bundleIdentifier: String?,
        bundleVersion: String? = nil,
        lastUsedAt: Date? = nil
    ) {
        self.name = name
        self.originalName = originalName ?? name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.bundleVersion = bundleVersion
        self.lastUsedAt = lastUsedAt
    }

    func withLastUsedAt(_ date: Date?) -> ApplicationRecord {
        ApplicationRecord(
            name: name,
            originalName: originalName,
            url: url,
            bundleIdentifier: bundleIdentifier,
            bundleVersion: bundleVersion,
            lastUsedAt: date
        )
    }
}

enum ApplicationAliases {
    static func key(for application: ApplicationRecord) -> String {
        application.bundleIdentifier ?? "path:\(application.url.path)"
    }

    static func applying(_ aliases: [String: String], to application: ApplicationRecord) -> ApplicationRecord {
        let alias = aliases[key(for: application)]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = alias.flatMap { $0.isEmpty ? nil : $0 } ?? application.originalName
        return ApplicationRecord(
            name: displayName,
            originalName: application.originalName,
            url: application.url,
            bundleIdentifier: application.bundleIdentifier,
            bundleVersion: application.bundleVersion,
            lastUsedAt: application.lastUsedAt
        )
    }
}

enum ApplicationExclusions {
    static func applying(_ excludedKeys: Set<String>, to applications: [ApplicationRecord]) -> [ApplicationRecord] {
        applications.filter { !excludedKeys.contains(ApplicationAliases.key(for: $0)) }
    }
}

enum ApplicationRecency {
    static func applying(_ timestamps: [String: TimeInterval], to application: ApplicationRecord) -> ApplicationRecord {
        guard let timestamp = timestamps[ApplicationAliases.key(for: application)] else { return application }
        let persisted = Date(timeIntervalSince1970: timestamp)
        return application.withLastUsedAt(max(application.lastUsedAt ?? .distantPast, persisted))
    }
}

enum MatchTier: Int, Comparable, Sendable {
    case exact
    case prefix
    case wordPrefix
    case substring
    case acronym
    case subsequence
    case typo
    case empty

    static func < (lhs: MatchTier, rhs: MatchTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct ApplicationMatch: Equatable, Sendable {
    let application: ApplicationRecord
    let tier: MatchTier

    var score: Int { 10_000 - tier.rawValue * 1_000 }
}

enum SpotlightModel {
    static let resultLimit = 6

    static func matches(
        query: String,
        applications: [ApplicationRecord],
        limit: Int = resultLimit
    ) -> [ApplicationMatch] {
        let query = normalized(query)
        let matched = applications.compactMap { application -> ApplicationMatch? in
            let searchTerms = Set([application.name, application.originalName, application.bundleIdentifier]
                .compactMap { $0 }
                .map(normalized))
            guard let tier = searchTerms.compactMap({ matchTier(query: query, name: $0) }).min() else {
                return nil
            }
            return ApplicationMatch(application: application, tier: tier)
        }
        return matched.sorted {
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            if $0.application.lastUsedAt != $1.application.lastUsedAt {
                return ($0.application.lastUsedAt ?? .distantPast) > ($1.application.lastUsedAt ?? .distantPast)
            }
            let nameOrder = $0.application.name.localizedCaseInsensitiveCompare($1.application.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return $0.application.url.path < $1.application.url.path
        }.prefix(limit).map { $0 }
    }

    static func uniqueMatch(query: String, matches: [ApplicationMatch]) -> ApplicationRecord? {
        let query = normalized(query)
        guard query.count >= 2 else { return nil }
        if matches.count == 1 { return matches[0].application }

        guard query.count >= 3,
              let first = matches.first,
              first.tier <= .wordPrefix,
              matches.dropFirst().first?.tier ?? .empty > .wordPrefix else { return nil }
        return first.application
    }

    static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .joined(separator: " ")
    }

    private static func matchTier(query: String, name: String) -> MatchTier? {
        guard !query.isEmpty else { return .empty }
        guard !name.isEmpty else { return nil }
        if name == query { return .exact }
        if name.hasPrefix(query) { return .prefix }

        let words = name.split(separator: " ").map(String.init)
        if words.contains(where: { $0.hasPrefix(query) }) { return .wordPrefix }
        if name.range(of: query) != nil { return .substring }

        let initials = String(words.compactMap(\.first))
        if initials.hasPrefix(query.replacingOccurrences(of: " ", with: "")) { return .acronym }

        if query.count >= 4, subsequenceGaps(query: query, in: name) != nil {
            return .subsequence
        }

        guard query.count >= 4 else { return nil }
        let typoAllowance = max(1, min(3, query.count / 4))
        let typoTargets = [name] + words + words.indices.map { words[$0...].joined(separator: " ") }
        let distances = typoTargets.map { target in
            let comparable = String(target.prefix(max(query.count, min(target.count, query.count + typoAllowance))))
            return editDistance(query, comparable)
        }
        guard let distance = distances.min(), distance <= typoAllowance else { return nil }
        return .typo
    }

    private static func subsequenceGaps(query: String, in name: String) -> Int? {
        var cursor = name.startIndex
        var gaps = 0
        var previous: String.Index?
        for character in query where character != " " {
            guard let found = name[cursor...].firstIndex(of: character) else { return nil }
            if let previous { gaps += name.distance(from: name.index(after: previous), to: found) }
            previous = found
            cursor = name.index(after: found)
        }
        return gaps
    }

    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, right) in b.enumerated() {
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + (left == right ? 0 : 1)
                )
            }
            previous = current
        }
        return previous[b.count]
    }
}
