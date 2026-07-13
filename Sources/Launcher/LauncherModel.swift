import Foundation

struct ApplicationRecord: Hashable, Sendable {
    let name: String
    let url: URL
    let bundleIdentifier: String?
}

struct ApplicationMatch: Equatable, Sendable {
    let application: ApplicationRecord
    let score: Int
}

enum LauncherModel {
    static let resultLimit = 10

    static func matches(query: String, applications: [ApplicationRecord], limit: Int = resultLimit) -> [ApplicationMatch] {
        let query = normalized(query)
        let scored = applications.compactMap { application -> ApplicationMatch? in
            guard let score = score(query: query, name: normalized(application.name)) else { return nil }
            return ApplicationMatch(application: application, score: score)
        }
        return scored.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            let nameOrder = $0.application.name.localizedCaseInsensitiveCompare($1.application.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return $0.application.url.path < $1.application.url.path
        }.prefix(limit).map { $0 }
    }

    static func uniqueExactMatch(query: String, applications: [ApplicationRecord]) -> ApplicationRecord? {
        let query = normalized(query)
        guard query.count >= 2 else { return nil }
        let exact = applications.filter { normalized($0.name) == query }
        return exact.count == 1 ? exact[0] : nil
    }

    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private static func score(query: String, name: String) -> Int? {
        guard !query.isEmpty else { return 1_000 }
        guard !name.isEmpty else { return nil }
        if name == query { return 10_000 }
        if name.hasPrefix(query) { return 9_000 - (name.count - query.count) }

        let words = name.split(separator: " ").map(String.init)
        if let word = words.first(where: { $0.hasPrefix(query) }) {
            return 8_700 - (word.count - query.count)
        }
        if let range = name.range(of: query) {
            let offset = name.distance(from: name.startIndex, to: range.lowerBound)
            return 8_300 - offset * 12 - (name.count - query.count)
        }

        let initials = String(words.compactMap(\.first))
        if initials.hasPrefix(query.replacingOccurrences(of: " ", with: "")) {
            return 7_900 - (initials.count - query.count)
        }

        if let gaps = subsequenceGaps(query: query, in: name) {
            return 7_200 - gaps * 16 - (name.count - query.count)
        }

        let typoAllowance = max(1, min(3, query.count / 4))
        let typoTargets = [name] + words + words.indices.map { words[$0...].joined(separator: " ") }
        let distances = typoTargets.map { target in
            let comparable = String(target.prefix(max(query.count, min(target.count, query.count + typoAllowance))))
            return editDistance(query, comparable)
        }
        guard let distance = distances.min(), distance <= typoAllowance else { return nil }
        return 7_600 - distance * 180 - abs(name.count - query.count)
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
