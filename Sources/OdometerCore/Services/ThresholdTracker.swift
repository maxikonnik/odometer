import Foundation

/// Remembers which notification thresholds have already fired for each limit,
/// so a threshold announces itself at most once per limit window.
public struct ThresholdTracker: Sendable {
    /// Hysteresis margin (percentage points) below a threshold for re-arming.
    /// Server percentages are whole numbers; without margin, oscillation around
    /// a boundary (e.g., 81 → 79 → 81) would re-fire the threshold on every
    /// up-crossing, spamming the user when they're near a limit.
    public static let rearmMargin: Double = 5

    public var thresholds: [Double] {
        didSet { if thresholds != oldValue { fired = [:] } }
    }

    private var fired: [LimitKind: Set<Double>] = [:]
    private var windows: [LimitKind: Date?] = [:]

    public init(thresholds: [Double] = [80, 95]) {
        self.thresholds = thresholds
    }

    public mutating func newlyCrossed(_ limit: UsageLimit) -> [Double] {
        if let known = windows[limit.kind], known != limit.resetsAt {
            fired[limit.kind] = []
        }
        windows[limit.kind] = limit.resetsAt

        // Falling back below an already-fired threshold re-arms it. This is
        // what actually re-arms limits whose resetsAt is permanently nil
        // (UsageDecoder.swift can produce those): the window-change check
        // above can never distinguish a still-nil value from a new window,
        // but a rolling window that resets also drops the percentage, which
        // this catches regardless of resetsAt.
        var alreadyFired = (fired[limit.kind] ?? []).filter { limit.percent >= $0 - Self.rearmMargin }

        let crossed = thresholds
            .sorted()
            .filter { limit.percent >= $0 && !alreadyFired.contains($0) }

        alreadyFired.formUnion(crossed)
        fired[limit.kind] = alreadyFired
        return crossed
    }
}
