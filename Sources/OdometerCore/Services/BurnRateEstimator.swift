import Foundation

public enum BurnForecast: Equatable, Sendable {
    case insufficientData
    case idle
    case lastsUntilReset
    case exhausts(at: Date, percentPerHour: Double)
}

/// Estimates how fast a limit is being consumed by fitting a least-squares
/// line through the percentages observed over the last half hour.
public struct BurnRateEstimator: Sendable {
    public static let windowSeconds: TimeInterval = 1800
    public static let minimumSpanSeconds: TimeInterval = 600

    private var samples: [(percent: Double, date: Date)] = []

    public init() {}

    public mutating func record(percent: Double, at date: Date) {
        // The session limit is a *rolling* five-hour window, so the percentage
        // legitimately falls as old usage ages out — that is idleness, not a
        // rollover, and the samples stay. Only a reading that has more than
        // halved means the window itself emptied, which makes every earlier
        // sample describe a period that no longer exists.
        if let last = samples.last, percent < last.percent / 2 {
            samples.removeAll()
        }
        samples.append((percent, date))
        samples.removeAll { date.timeIntervalSince($0.date) > Self.windowSeconds }
    }

    public func forecast(now: Date, resetsAt: Date?) -> BurnForecast {
        let window = samples.filter { now.timeIntervalSince($0.date) <= Self.windowSeconds }
        guard let first = window.first, let last = window.last,
              last.date.timeIntervalSince(first.date) >= Self.minimumSpanSeconds
        else { return .insufficientData }

        let slope = percentPerHour(window)
        guard slope > 0.001 else { return .idle }

        let remaining = max(0, 100 - last.percent)
        let secondsLeft = remaining / slope * 3600
        let exhaustsAt = now.addingTimeInterval(secondsLeft)

        if let resetsAt, exhaustsAt >= resetsAt { return .lastsUntilReset }
        return .exhausts(at: exhaustsAt, percentPerHour: slope)
    }

    private func percentPerHour(_ window: [(percent: Double, date: Date)]) -> Double {
        let base = window[0].date.timeIntervalSince1970
        let xs = window.map { ($0.date.timeIntervalSince1970 - base) / 3600 }
        let ys = window.map(\.percent)
        let count = Double(xs.count)
        let meanX = xs.reduce(0, +) / count
        let meanY = ys.reduce(0, +) / count

        var numerator = 0.0
        var denominator = 0.0
        for (x, y) in zip(xs, ys) {
            numerator += (x - meanX) * (y - meanY)
            denominator += (x - meanX) * (x - meanX)
        }
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }
}
