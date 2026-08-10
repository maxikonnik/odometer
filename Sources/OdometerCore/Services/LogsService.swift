import Foundation

public struct TokenStats: Equatable, Sendable {
    public var total = TokenCounts()
    public var byModel: [String: TokenCounts] = [:]
    public var byProject: [String: TokenCounts] = [:]
    public var estimatedCostUSD: Double?
    public var hasUnpricedModel = false

    public init() {}
}

public final class LogsService {
    private struct Cache: Codable {
        var day: String = ""
        var cursors: [String: FileCursor] = [:]
        var seenKeys: Set<String> = []
        var byModel: [String: TokenCounts] = [:]
        var byProject: [String: TokenCounts] = [:]
    }

    private let projectsDirectory: URL
    private let cacheURL: URL
    private let calendar: Calendar
    private var cache = Cache()
    private var loaded = false

    public init(projectsDirectory: URL, cacheURL: URL, calendar: Calendar = .current) {
        self.projectsDirectory = projectsDirectory
        self.cacheURL = cacheURL
        self.calendar = calendar
    }

    public func refresh(now: Date) throws -> TokenStats {
        loadCacheIfNeeded()

        let day = dayKey(for: now)
        if cache.day != day {
            cache.day = day
            cache.seenKeys = []
            cache.byModel = [:]
            cache.byProject = [:]
        }

        for file in transcriptFiles() {
            var cursor = cache.cursors[file.path] ?? FileCursor()
            let lines = (try? IncrementalFileReader.newLines(at: file, cursor: &cursor)) ?? []
            cache.cursors[file.path] = cursor
            for line in lines {
                guard let entry = LogParser.entry(fromLine: line),
                      dayKey(for: entry.timestamp) == day,
                      cache.seenKeys.insert(entry.dedupeKey).inserted
                else { continue }
                cache.byModel[entry.model, default: TokenCounts()] += entry.tokens
                cache.byProject[project(fromCwd: entry.cwd), default: TokenCounts()] += entry.tokens
            }
        }

        saveCache()
        return stats()
    }

    private func stats() -> TokenStats {
        var stats = TokenStats()
        stats.byModel = cache.byModel
        stats.byProject = cache.byProject

        var cost = 0.0
        for (model, counts) in cache.byModel {
            stats.total += counts
            if let modelCost = Pricing.cost(of: counts, model: model) {
                cost += modelCost
            } else {
                stats.hasUnpricedModel = true
            }
        }
        stats.estimatedCostUSD = cache.byModel.isEmpty ? nil : cost
        return stats
    }

    private func transcriptFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
    }

    private func project(fromCwd cwd: String) -> String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "—" : name
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func loadCacheIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode(Cache.self, from: data)
        else { return }
        cache = decoded
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: cacheURL, options: .atomic)
    }
}
