import Foundation

public struct ModelPrice: Equatable, Sendable {
    public let inputPerMTok: Double
    public let outputPerMTok: Double
    public let cacheWritePerMTok: Double
    public let cacheReadPerMTok: Double

    public init(input: Double, output: Double) {
        self.inputPerMTok = input
        self.outputPerMTok = output
        self.cacheWritePerMTok = input * 1.25
        self.cacheReadPerMTok = input * 0.1
    }
}

public enum Pricing {
    /// US dollars per million tokens. Cache writes bill at 1.25x the input
    /// rate (5-minute TTL) and cache reads at 0.1x, so both are derived.
    public static let table: [String: ModelPrice] = [
        "claude-fable-5": ModelPrice(input: 10, output: 50),
        "claude-mythos-5": ModelPrice(input: 10, output: 50),
        "claude-opus-5": ModelPrice(input: 5, output: 25),
        "claude-opus-4-8": ModelPrice(input: 5, output: 25),
        "claude-opus-4-7": ModelPrice(input: 5, output: 25),
        "claude-opus-4-6": ModelPrice(input: 5, output: 25),
        "claude-sonnet-5": ModelPrice(input: 3, output: 15),
        "claude-sonnet-4-6": ModelPrice(input: 3, output: 15),
        "claude-haiku-4-5": ModelPrice(input: 1, output: 5),
    ]

    /// Transcripts record dated snapshot ids such as `claude-haiku-4-5-20251001`,
    /// so an exact miss falls back to the longest matching prefix.
    public static func price(forModel model: String) -> ModelPrice? {
        if let exact = table[model] { return exact }
        return table
            .filter { model.hasPrefix($0.key) }
            .max { $0.key.count < $1.key.count }?
            .value
    }

    public static func cost(of counts: TokenCounts, model: String) -> Double? {
        guard let price = price(forModel: model) else { return nil }
        let million = 1_000_000.0
        return Double(counts.input) / million * price.inputPerMTok
            + Double(counts.output) / million * price.outputPerMTok
            + Double(counts.cacheCreation) / million * price.cacheWritePerMTok
            + Double(counts.cacheRead) / million * price.cacheReadPerMTok
    }
}
