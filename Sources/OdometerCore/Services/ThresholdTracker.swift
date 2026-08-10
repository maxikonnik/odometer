import Foundation

/// Remembers which notification thresholds have already fired for each limit,
/// so a threshold announces itself at most once per limit window.
public struct ThresholdTracker: Sendable {
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

        var alreadyFired = fired[limit.kind] ?? []
        let crossed = thresholds
            .sorted()
            .filter { limit.percent >= $0 && !alreadyFired.contains($0) }

        alreadyFired.formUnion(crossed)
        fired[limit.kind] = alreadyFired
        return crossed
    }
}
