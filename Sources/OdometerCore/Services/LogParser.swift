import Foundation

public struct TranscriptEntry: Equatable, Sendable {
    public let dedupeKey: String
    public let model: String
    public let timestamp: Date
    public let cwd: String
    public let tokens: TokenCounts
}

public enum LogParser {
    private struct Line: Decodable {
        struct Message: Decodable {
            struct Usage: Decodable {
                let inputTokens: Int?
                let outputTokens: Int?
                let cacheCreationInputTokens: Int?
                let cacheReadInputTokens: Int?
            }
            let id: String?
            let model: String?
            let usage: Usage?
        }
        let requestId: String?
        let timestamp: String?
        let cwd: String?
        let message: Message?
    }

    /// Returns nil for any line that is not a billable assistant message —
    /// user turns, metadata records, and corrupt lines all fall in that bucket
    /// and are skipped rather than treated as errors.
    public static func entry(fromLine line: String) -> TranscriptEntry? {
        guard let data = line.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let parsed = try? decoder.decode(Line.self, from: data),
              let message = parsed.message,
              let usage = message.usage,
              let model = message.model,
              let messageId = message.id,
              let timestampString = parsed.timestamp,
              let timestamp = ISO8601.date(from: timestampString)
        else { return nil }

        return TranscriptEntry(
            dedupeKey: "\(messageId):\(parsed.requestId ?? "")",
            model: model,
            timestamp: timestamp,
            cwd: parsed.cwd ?? "",
            tokens: TokenCounts(
                input: usage.inputTokens ?? 0,
                output: usage.outputTokens ?? 0,
                cacheCreation: usage.cacheCreationInputTokens ?? 0,
                cacheRead: usage.cacheReadInputTokens ?? 0
            )
        )
    }
}
