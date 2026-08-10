import Foundation

public enum LimitKind: String, Sendable, CaseIterable {
    case session = "session"
    case weeklyAll = "weekly_all"
    case weeklyScoped = "weekly_scoped"
}

public struct UsageLimit: Equatable, Sendable {
    public let kind: LimitKind
    public let label: String
    public let percent: Double
    public let resetsAt: Date?
    public let isActive: Bool

    public init(kind: LimitKind, label: String, percent: Double, resetsAt: Date?, isActive: Bool) {
        self.kind = kind
        self.label = label
        self.percent = percent
        self.resetsAt = resetsAt
        self.isActive = isActive
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let limits: [UsageLimit]
    public let fetchedAt: Date

    public init(limits: [UsageLimit], fetchedAt: Date) {
        self.limits = limits
        self.fetchedAt = fetchedAt
    }

    public func limit(_ kind: LimitKind) -> UsageLimit? {
        limits.first { $0.kind == kind }
    }
}
