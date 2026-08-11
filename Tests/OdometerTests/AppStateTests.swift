import Foundation
import Testing
@testable import OdometerCore

private struct StaticUsageProvider: UsageProviding {
    let result: Result<UsageSnapshot, Error>
    init(_ result: Result<UsageSnapshot, Error>) { self.result = result }
    func fetch() async throws -> UsageSnapshot { try result.get() }
}

private struct SequenceUsageProvider: UsageProviding {
    let box: ResultBox
    func fetch() async throws -> UsageSnapshot { try await box.next() }
}

private actor ResultBox {
    private var results: [Result<UsageSnapshot, Error>]
    init(_ results: [Result<UsageSnapshot, Error>]) { self.results = results }
    func next() throws -> UsageSnapshot {
        guard !results.isEmpty else { throw UsageServiceError.decodingFailed }
        return try results.removeFirst().get()
    }
}

@Suite @MainActor struct AppStateTests {
    private let now = Date(timeIntervalSince1970: 1_786_400_000)

    private func snapshot(session: Double, weekly: Double = 20,
                          fetchedAt: Date? = nil) -> UsageSnapshot {
        UsageSnapshot(
            limits: [
                // Five hours out, because that is the session window this
                // fixture stands for. An hour would put every forecast past the
                // reset and make the exhaustion path untestable.
                UsageLimit(kind: .session, label: "Сессия 5 ч", percent: session,
                           resetsAt: now.addingTimeInterval(18_000), isActive: true),
                UsageLimit(kind: .weeklyAll, label: "Неделя", percent: weekly,
                           resetsAt: now.addingTimeInterval(86_400), isActive: false),
            ],
            fetchedAt: fetchedAt ?? now
        )
    }

    private func makeState(provider: any UsageProviding) throws -> AppState {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "odometer-appstate-\(UUID().uuidString)"
        // Keep the failure paths from appending to the developer's real log.
        Diagnostics.fileURL = root.appendingPathComponent("odometer.log")
        return AppState(
            usage: provider,
            logs: LogsService(
                projectsDirectory: root.appendingPathComponent("projects"),
                cacheURL: root.appendingPathComponent("cache.json")
            ),
            attention: AttentionService(
                store: AttentionStore(directory: root.appendingPathComponent("attention"))
            ),
            settings: Settings(defaults: try #require(UserDefaults(suiteName: suite))),
            planBadge: "Max 5×"
        )
    }

    @Test func successfulRefreshPublishesSnapshot() async throws {
        let state = try makeState(provider: StaticUsageProvider(.success(snapshot(session: 41))))
        await state.refreshUsage(now: now)
        #expect(state.snapshot?.limit(.session)?.percent == 41)
        #expect(state.usageState == .ok)
    }

    @Test func missingCredentialsSurfaceAsNoCredentials() async throws {
        let state = try makeState(
            provider: StaticUsageProvider(.failure(KeychainError.itemNotFound))
        )
        await state.refreshUsage(now: now)
        #expect(state.usageState == .noCredentials)
        #expect(state.snapshot == nil)
    }

    @Test func networkFailureKeepsTheLastGoodSnapshot() async throws {
        let box = ResultBox([
            .success(snapshot(session: 41)),
            .failure(UsageServiceError.httpStatus(500)),
        ])
        let state = try makeState(provider: SequenceUsageProvider(box: box))

        await state.refreshUsage(now: now)
        await state.refreshUsage(now: now.addingTimeInterval(60))

        #expect(state.snapshot?.limit(.session)?.percent == 41)
        #expect(state.usageState == .unavailable)
    }

    @Test func backoffGrowsOnFailureAndResetsOnSuccess() async throws {
        let box = ResultBox([
            .failure(UsageServiceError.httpStatus(500)),
            .success(snapshot(session: 10)),
        ])
        let state = try makeState(provider: SequenceUsageProvider(box: box))

        await state.refreshUsage(now: now)
        #expect(state.nextRefreshDelay == 120)

        await state.refreshUsage(now: now.addingTimeInterval(120))
        #expect(state.nextRefreshDelay == 60)
    }

    @Test func forecastAccumulatesAcrossRefreshes() async throws {
        let box = ResultBox([
            .success(snapshot(session: 50, fetchedAt: now)),
            .success(snapshot(session: 60, fetchedAt: now.addingTimeInterval(1800))),
        ])
        let state = try makeState(provider: SequenceUsageProvider(box: box))

        await state.refreshUsage(now: now)
        #expect(state.forecast == .insufficientData)

        await state.refreshUsage(now: now.addingTimeInterval(1800))
        guard case .exhausts = state.forecast else {
            Issue.record("expected an exhaustion forecast, got \(state.forecast)")
            return
        }
    }

    @Test func menuBarPercentFollowsTheSelectedLimit() async throws {
        let state = try makeState(
            provider: StaticUsageProvider(.success(snapshot(session: 41, weekly: 38)))
        )
        await state.refreshUsage(now: now)

        #expect(state.menuBarPercent() == 41)
        state.settings.menuBarLimit = .weeklyAll
        #expect(state.menuBarPercent() == 38)
        state.settings.menuBarLimit = .weeklyScoped
        #expect(state.menuBarPercent() == nil)
    }

    @Test func lastUpdatedTextIsNilWhileHealthy() async throws {
        let state = try makeState(provider: StaticUsageProvider(.success(snapshot(session: 41))))
        await state.refreshUsage(now: now)
        #expect(state.staleText(now: now.addingTimeInterval(30)) == nil)
    }

    @Test func lastUpdatedTextAppearsWhenDataGoesStale() async throws {
        let state = try makeState(provider: StaticUsageProvider(.success(snapshot(session: 41))))
        await state.refreshUsage(now: now)
        #expect(state.staleText(now: now.addingTimeInterval(260)) == "обновлено 4 мин назад")
    }
}
