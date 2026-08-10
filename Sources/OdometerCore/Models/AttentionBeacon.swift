import Foundation

public struct AttentionBeacon: Codable, Equatable, Sendable, Identifiable {
    public let sessionId: String
    public let cwd: String
    public let termProgram: String?
    public let createdAt: Date

    public var id: String { sessionId }

    public init(sessionId: String, cwd: String, termProgram: String?, createdAt: Date) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.termProgram = termProgram
        self.createdAt = createdAt
    }
}
