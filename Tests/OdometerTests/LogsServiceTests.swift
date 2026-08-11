import Foundation
import Testing
@testable import OdometerCore

@Suite struct LogParserTests {
    private let line = """
    {"type":"assistant","uuid":"u-1","sessionId":"s-1","requestId":"req-1",
     "timestamp":"2026-08-09T21:34:35.118Z","cwd":"/Users/x/Documents/Claude/healthcoach",
     "message":{"id":"msg-1","model":"claude-haiku-4-5-20251001","role":"assistant",
       "usage":{"input_tokens":10,"output_tokens":293,
                "cache_creation_input_tokens":8379,"cache_read_input_tokens":17794}}}
    """

    @Test func extractsTokensModelAndProject() throws {
        let entry = try #require(LogParser.entry(fromLine: line))
        #expect(entry.model == "claude-haiku-4-5-20251001")
        #expect(entry.cwd == "/Users/x/Documents/Claude/healthcoach")
        #expect(entry.tokens == TokenCounts(input: 10, output: 293,
                                            cacheCreation: 8379, cacheRead: 17794))
    }

    @Test func dedupeKeyCombinesMessageAndRequestIds() throws {
        let entry = try #require(LogParser.entry(fromLine: line))
        #expect(entry.dedupeKey == "msg-1:req-1")
    }

    @Test func lineWithoutUsageIsSkipped() {
        let userLine = """
        {"type":"user","uuid":"u-2","timestamp":"2026-08-09T21:34:35.118Z","cwd":"/x",
         "message":{"role":"user","content":"hi"}}
        """
        #expect(LogParser.entry(fromLine: userLine) == nil)
    }

    @Test func malformedLineIsSkipped() {
        #expect(LogParser.entry(fromLine: "{not json") == nil)
        #expect(LogParser.entry(fromLine: "") == nil)
    }

    @Test func missingCacheFieldsDefaultToZero() throws {
        let sparse = """
        {"type":"assistant","requestId":"r","timestamp":"2026-08-09T21:34:35Z","cwd":"/x",
         "message":{"id":"m","model":"claude-opus-5","usage":{"input_tokens":5,"output_tokens":7}}}
        """
        let entry = try #require(LogParser.entry(fromLine: sparse))
        #expect(entry.tokens == TokenCounts(input: 5, output: 7))
    }
}

@Suite final class IncrementalFileReaderTests {
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func readsOnlyNewlyAppendedLines() throws {
        let file = directory.appendingPathComponent("a.jsonl")
        try "one\ntwo\n".write(to: file, atomically: true, encoding: .utf8)

        var cursor = FileCursor()
        #expect(try IncrementalFileReader.newLines(at: file, cursor: &cursor) == ["one", "two"])

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("three\n".utf8))
        try handle.close()

        #expect(try IncrementalFileReader.newLines(at: file, cursor: &cursor) == ["three"])
    }

    @Test func secondReadWithoutChangesReturnsNothing() throws {
        let file = directory.appendingPathComponent("b.jsonl")
        try "one\n".write(to: file, atomically: true, encoding: .utf8)
        var cursor = FileCursor()
        _ = try IncrementalFileReader.newLines(at: file, cursor: &cursor)
        #expect(try IncrementalFileReader.newLines(at: file, cursor: &cursor) == [])
    }

    @Test func truncatedFileIsRereadFromStart() throws {
        let file = directory.appendingPathComponent("c.jsonl")
        try "one\ntwo\nthree\n".write(to: file, atomically: true, encoding: .utf8)
        var cursor = FileCursor()
        _ = try IncrementalFileReader.newLines(at: file, cursor: &cursor)

        try "fresh\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(try IncrementalFileReader.newLines(at: file, cursor: &cursor) == ["fresh"])
    }

    @Test func partialTrailingLineIsHeldBackUntilComplete() throws {
        let file = directory.appendingPathComponent("d.jsonl")
        try "one\npar".write(to: file, atomically: true, encoding: .utf8)
        var cursor = FileCursor()
        #expect(try IncrementalFileReader.newLines(at: file, cursor: &cursor) == ["one"])

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("tial\n".utf8))
        try handle.close()

        #expect(try IncrementalFileReader.newLines(at: file, cursor: &cursor) == ["partial"])
    }
}

@Suite final class LogsServiceTests {
    private let root: URL
    private let projects: URL
    private let cache: URL
    private let today = Date(timeIntervalSince1970: 1_786_400_000) // 2026-08-08 UTC

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        projects = root.appendingPathComponent("projects")
        cache = root.appendingPathComponent("cache.json")
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func line(
        messageId: String,
        requestId: String,
        model: String = "claude-opus-5",
        cwd: String = "/Users/x/proj-a",
        at date: Date,
        input: Int = 100,
        output: Int = 200
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return """
        {"type":"assistant","requestId":"\(requestId)","timestamp":"\(formatter.string(from: date))",\
        "cwd":"\(cwd)","message":{"id":"\(messageId)","model":"\(model)",\
        "usage":{"input_tokens":\(input),"output_tokens":\(output),\
        "cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """
    }

    private func write(_ lines: [String], to name: String) throws {
        let dir = projects.appendingPathComponent("proj-a")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n")
            .write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func makeService() -> LogsService {
        LogsService(projectsDirectory: projects, cacheURL: cache, calendar: utcCalendar)
    }

    @Test func aggregatesTokensForToday() throws {
        try write([
            line(messageId: "m1", requestId: "r1", at: today),
            line(messageId: "m2", requestId: "r2", at: today),
        ], to: "s.jsonl")

        let stats = try makeService().refresh(now: today)
        #expect(stats.total == TokenCounts(input: 200, output: 400))
    }

    @Test func duplicateMessageRequestPairCountedOnce() throws {
        try write([
            line(messageId: "m1", requestId: "r1", at: today),
            line(messageId: "m1", requestId: "r1", at: today),
        ], to: "s.jsonl")

        let stats = try makeService().refresh(now: today)
        #expect(stats.total == TokenCounts(input: 100, output: 200))
    }

    @Test func entriesFromOtherDaysAreExcluded() throws {
        let yesterday = today.addingTimeInterval(-86_400)
        try write([
            line(messageId: "m1", requestId: "r1", at: yesterday),
            line(messageId: "m2", requestId: "r2", at: today),
        ], to: "s.jsonl")

        let stats = try makeService().refresh(now: today)
        #expect(stats.total == TokenCounts(input: 100, output: 200))
    }

    @Test func breakdownByModelAndProject() throws {
        try write([
            line(messageId: "m1", requestId: "r1", model: "claude-opus-5", cwd: "/Users/x/alpha", at: today),
            line(messageId: "m2", requestId: "r2", model: "claude-haiku-4-5", cwd: "/Users/x/beta", at: today),
        ], to: "s.jsonl")

        let stats = try makeService().refresh(now: today)
        #expect(stats.byModel["claude-opus-5"] == TokenCounts(input: 100, output: 200))
        #expect(stats.byModel["claude-haiku-4-5"] == TokenCounts(input: 100, output: 200))
        #expect(stats.byProject["alpha"] == TokenCounts(input: 100, output: 200))
        #expect(stats.byProject["beta"] == TokenCounts(input: 100, output: 200))
    }

    @Test func costSumsPerModelRates() throws {
        try write([
            line(messageId: "m1", requestId: "r1", model: "claude-opus-5",
                 at: today, input: 1_000_000, output: 0)
        ], to: "s.jsonl")

        let stats = try makeService().refresh(now: today)
        let cost = try #require(stats.estimatedCostUSD)
        #expect(abs(cost - 5) < 0.0001)
        #expect(!stats.hasUnpricedModel)
    }

    @Test func unpricedModelIsFlaggedAndExcludedFromCost() throws {
        try write([
            line(messageId: "m1", requestId: "r1", model: "mystery-model",
                 at: today, input: 1_000_000, output: 0)
        ], to: "s.jsonl")

        let stats = try makeService().refresh(now: today)
        #expect(stats.hasUnpricedModel)
        #expect(stats.estimatedCostUSD == nil)
        #expect(stats.byModel["mystery-model"] == TokenCounts(input: 1_000_000))
    }

    @Test func corruptLinesDoNotStopTheFile() throws {
        try write([
            "{oops",
            line(messageId: "m1", requestId: "r1", at: today),
        ], to: "s.jsonl")

        let stats = try makeService().refresh(now: today)
        #expect(stats.total == TokenCounts(input: 100, output: 200))
    }

    @Test func appendedLinesAccumulateAcrossRefreshes() throws {
        try write([line(messageId: "m1", requestId: "r1", at: today)], to: "s.jsonl")
        let service = makeService()
        _ = try service.refresh(now: today)

        let file = projects.appendingPathComponent("proj-a/s.jsonl")
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((line(messageId: "m2", requestId: "r2", at: today) + "\n").utf8))
        try handle.close()

        let stats = try service.refresh(now: today)
        #expect(stats.total == TokenCounts(input: 200, output: 400))
    }

    @Test func totalsSurviveARestartViaCache() throws {
        try write([line(messageId: "m1", requestId: "r1", at: today)], to: "s.jsonl")
        _ = try makeService().refresh(now: today)

        let stats = try makeService().refresh(now: today)
        #expect(stats.total == TokenCounts(input: 100, output: 200))
    }

    @Test func dayRolloverResetsTotals() throws {
        try write([line(messageId: "m1", requestId: "r1", at: today)], to: "s.jsonl")
        let service = makeService()
        _ = try service.refresh(now: today)

        let stats = try service.refresh(now: today.addingTimeInterval(86_400))
        #expect(stats.total == TokenCounts())
    }

    @Test func missingProjectsDirectoryYieldsEmptyStats() throws {
        try FileManager.default.removeItem(at: projects)
        let stats = try makeService().refresh(now: today)
        #expect(stats.total == TokenCounts())
    }
}
