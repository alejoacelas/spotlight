import Foundation

final class LauncherMetrics {
    private let defaults: UserDefaults
    private var searchCount: Int
    private var searchTotalMicroseconds: Int
    private var searchWorstMicroseconds: Int
    private var selections: [String: Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        searchCount = defaults.integer(forKey: "metricSearchCount")
        searchTotalMicroseconds = defaults.integer(forKey: "metricSearchTotalMicroseconds")
        searchWorstMicroseconds = defaults.integer(forKey: "metricSearchWorstMicroseconds")
        selections = defaults.dictionary(forKey: "metricSelections")?.compactMapValues {
            ($0 as? NSNumber)?.intValue
        } ?? [:]
    }

    func recordSearch(seconds: TimeInterval) {
        let microseconds = max(0, Int(seconds * 1_000_000))
        searchCount += 1
        searchTotalMicroseconds += microseconds
        searchWorstMicroseconds = max(searchWorstMicroseconds, microseconds)
        if searchCount.isMultiple(of: 25) { persistSearch() }
    }

    func recordSelection(applicationKey: String) {
        selections[applicationKey, default: 0] += 1
        defaults.set(selections, forKey: "metricSelections")
    }

    private func persistSearch() {
        defaults.set(searchCount, forKey: "metricSearchCount")
        defaults.set(searchTotalMicroseconds, forKey: "metricSearchTotalMicroseconds")
        defaults.set(searchWorstMicroseconds, forKey: "metricSearchWorstMicroseconds")
    }
}
