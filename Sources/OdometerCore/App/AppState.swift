import Foundation
import Observation

public enum UsageState: Equatable, Sendable {
    case ok
    case noCredentials
    case unavailable
}

@MainActor
@Observable
public final class AppState {
    public private(set) var snapshot: UsageSnapshot?
    public private(set) var stats = TokenStats()
    public private(set) var forecast: BurnForecast = .insufficientData
    public private(set) var usageState: UsageState = .ok
    public private(set) var planBadge: String?

    public let attention: AttentionService
    public let settings: Settings
    public let notifier: ThresholdNotifier

    /// Seconds until the next poll; grows while the endpoint is failing.
    public var nextRefreshDelay: TimeInterval { backoff.delay }

    @ObservationIgnored private let usage: any UsageProviding
    @ObservationIgnored private let logs: LogsService
    @ObservationIgnored private var backoff = Backoff()
    @ObservationIgnored private var burn = BurnRateEstimator()

    public init(
        usage: any UsageProviding,
        logs: LogsService,
        attention: AttentionService,
        settings: Settings,
        planBadge: String? = nil
    ) {
        self.usage = usage
        self.logs = logs
        self.attention = attention
        self.settings = settings
        self.notifier = ThresholdNotifier(settings: settings)
        self.planBadge = planBadge
    }

    public func refreshUsage(now: Date) async {
        do {
            let fresh = try await usage.fetch()
            backoff.recordSuccess()
            snapshot = fresh
            usageState = .ok

            if let session = fresh.limit(.session) {
                burn.record(percent: session.percent, at: fresh.fetchedAt)
                forecast = burn.forecast(now: now, resetsAt: session.resetsAt)
            }
            notifier.process(snapshot: fresh)
        } catch {
            backoff.recordFailure()
            usageState = (error is KeychainError) ? .noCredentials : .unavailable
            Diagnostics.log("usage refresh failed: \(error)")
        }
    }

    public func refreshLogs(now: Date) {
        do {
            stats = try logs.refresh(now: now)
        } catch {
            Diagnostics.log("log refresh failed: \(error)")
        }
    }

    /// Set after launch: reading it from the Keychain can block on the system
    /// approval prompt, which must never sit in front of the status item.
    public func setPlanBadge(_ badge: String?) {
        planBadge = badge
    }

    public func menuBarPercent() -> Double? {
        snapshot?.limit(settings.menuBarLimit)?.percent
    }

    /// Nil while the readings are current; otherwise the greyed footer text.
    public func staleText(now: Date) -> String? {
        guard let fetchedAt = snapshot?.fetchedAt else { return nil }
        let age = now.timeIntervalSince(fetchedAt)
        guard age >= 120 else { return nil }
        return "обновлено \(Int(age / 60)) мин назад"
    }
}

public enum Diagnostics {
    public static var fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/odometer/odometer.log")

    public static func log(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }
}
