import Foundation
import Testing
@testable import OdometerCore

@Suite struct ThresholdTrackerTests {
    private let reset = Date(timeIntervalSince1970: 1_786_400_000)

    private func limit(_ percent: Double, resetsAt: Date? = nil,
                       kind: LimitKind = .session) -> UsageLimit {
        UsageLimit(kind: kind, label: "L", percent: percent,
                   resetsAt: resetsAt ?? reset, isActive: true)
    }

    @Test func noCrossingBelowFirstThreshold() {
        var tracker = ThresholdTracker(thresholds: [80, 95])
        #expect(tracker.newlyCrossed(limit(50)) == [])
    }

    @Test func crossingFiresOnce() {
        var tracker = ThresholdTracker(thresholds: [80, 95])
        #expect(tracker.newlyCrossed(limit(81)) == [80])
        #expect(tracker.newlyCrossed(limit(85)) == [])
    }

    @Test func jumpPastBothThresholdsFiresBoth() {
        var tracker = ThresholdTracker(thresholds: [80, 95])
        #expect(tracker.newlyCrossed(limit(97)) == [80, 95])
    }

    @Test func secondThresholdFiresLater() {
        var tracker = ThresholdTracker(thresholds: [80, 95])
        #expect(tracker.newlyCrossed(limit(82)) == [80])
        #expect(tracker.newlyCrossed(limit(96)) == [95])
    }

    @Test func windowChangeRearmsThresholds() {
        var tracker = ThresholdTracker(thresholds: [80, 95])
        _ = tracker.newlyCrossed(limit(90))
        let next = reset.addingTimeInterval(18_000)
        #expect(tracker.newlyCrossed(limit(90, resetsAt: next)) == [80])
    }

    @Test func limitsAreTrackedIndependently() {
        var tracker = ThresholdTracker(thresholds: [80])
        #expect(tracker.newlyCrossed(limit(90, kind: .session)) == [80])
        #expect(tracker.newlyCrossed(limit(90, kind: .weeklyAll)) == [80])
    }

    @Test func changingThresholdsRearms() {
        var tracker = ThresholdTracker(thresholds: [80])
        _ = tracker.newlyCrossed(limit(90))
        tracker.thresholds = [50, 80]
        #expect(tracker.newlyCrossed(limit(90)) == [50, 80])
    }

    @Test func droppingBelowThresholdRearmsIt() {
        var tracker = ThresholdTracker(thresholds: [80, 95])
        #expect(tracker.newlyCrossed(limit(81)) == [80])
        #expect(tracker.newlyCrossed(limit(70)) == [])
        #expect(tracker.newlyCrossed(limit(85)) == [80])
    }

    @Test func nilResetsAtLimitRearmsOnDropAndRecrosses() {
        func nilResetLimit(_ percent: Double) -> UsageLimit {
            UsageLimit(kind: .session, label: "L", percent: percent, resetsAt: nil, isActive: true)
        }
        var tracker = ThresholdTracker(thresholds: [80, 95])

        #expect(tracker.newlyCrossed(nilResetLimit(96)) == [80, 95])
        #expect(tracker.newlyCrossed(nilResetLimit(96)) == [])

        // Rolling window resets without ever reporting a new resetsAt.
        // Drop far below the margin to re-arm (well below 95 - 5 = 90).
        #expect(tracker.newlyCrossed(nilResetLimit(50)) == [])

        #expect(tracker.newlyCrossed(nilResetLimit(96)) == [80, 95])
    }

    @Test func hysteresisPreventsSpamaroundThreshold() {
        func nilResetLimit(_ percent: Double) -> UsageLimit {
            UsageLimit(kind: .session, label: "L", percent: percent, resetsAt: nil, isActive: true)
        }
        var tracker = ThresholdTracker(thresholds: [80, 95])

        // Cross the 80% threshold.
        #expect(tracker.newlyCrossed(nilResetLimit(81)) == [80])

        // Dip just below the threshold (1 point); with 5-point margin, the
        // threshold is still considered fired and does not re-arm.
        #expect(tracker.newlyCrossed(nilResetLimit(79)) == [])

        // Return to above threshold; threshold does not fire again.
        #expect(tracker.newlyCrossed(nilResetLimit(81)) == [])
    }
}
