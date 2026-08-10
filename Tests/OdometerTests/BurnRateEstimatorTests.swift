import Foundation
import Testing
@testable import OdometerCore

@Suite struct BurnRateEstimatorTests {
    private let start = Date(timeIntervalSince1970: 1_786_400_000)

    private func estimator(samples: [(Double, TimeInterval)]) -> BurnRateEstimator {
        var estimator = BurnRateEstimator()
        for (percent, offset) in samples {
            estimator.record(percent: percent, at: start.addingTimeInterval(offset))
        }
        return estimator
    }

    @Test func tooShortASpanIsInsufficient() {
        let estimator = estimator(samples: [(10, 0), (12, 300)]) // 5 minutes
        #expect(estimator.forecast(now: start.addingTimeInterval(300), resetsAt: nil) == .insufficientData)
    }

    @Test func singleSampleIsInsufficient() {
        let estimator = estimator(samples: [(10, 0)])
        #expect(estimator.forecast(now: start, resetsAt: nil) == .insufficientData)
    }

    @Test func flatUsageIsIdle() {
        let estimator = estimator(samples: [(10, 0), (10, 600), (10, 1200)])
        #expect(estimator.forecast(now: start.addingTimeInterval(1200), resetsAt: nil) == .idle)
    }

    @Test func decreasingUsageIsIdle() {
        let estimator = estimator(samples: [(30, 0), (20, 900)])
        #expect(estimator.forecast(now: start.addingTimeInterval(900), resetsAt: nil) == .idle)
    }

    @Test func steadyClimbProjectsExhaustion() throws {
        // 10% over 30 minutes = 20%/hour; from 60% there are 40% left = 2 hours.
        let estimator = estimator(samples: [(50, 0), (55, 900), (60, 1800)])
        let now = start.addingTimeInterval(1800)
        guard case let .exhausts(at, rate) = estimator.forecast(now: now, resetsAt: nil) else {
            Issue.record("expected an exhaustion forecast")
            return
        }
        #expect(abs(rate - 20) < 0.5)
        #expect(abs(at.timeIntervalSince(now) - 7200) < 120)
    }

    @Test func exhaustionAfterResetReportsLastsUntilReset() {
        let estimator = estimator(samples: [(10, 0), (11, 900), (12, 1800)])
        let now = start.addingTimeInterval(1800)
        #expect(estimator.forecast(now: now, resetsAt: now.addingTimeInterval(1800)) == .lastsUntilReset)
    }

    @Test func samplesOlderThanTheWindowAreDropped() {
        // A steep early climb followed by a flat half hour must read as idle.
        var estimator = BurnRateEstimator()
        estimator.record(percent: 0, at: start)
        estimator.record(percent: 50, at: start.addingTimeInterval(600))
        estimator.record(percent: 50, at: start.addingTimeInterval(3600))
        estimator.record(percent: 50, at: start.addingTimeInterval(5400))
        #expect(estimator.forecast(now: start.addingTimeInterval(5400), resetsAt: nil) == .idle)
    }

    @Test func windowResetAfterLimitRollover() {
        // A drop in percentage means a new limit window; older samples must go.
        var estimator = BurnRateEstimator()
        estimator.record(percent: 90, at: start)
        estimator.record(percent: 95, at: start.addingTimeInterval(600))
        estimator.record(percent: 2, at: start.addingTimeInterval(1200))
        #expect(estimator.forecast(now: start.addingTimeInterval(1200), resetsAt: nil) == .insufficientData)
    }
}
