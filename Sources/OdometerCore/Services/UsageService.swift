import Foundation

public enum UsageServiceError: Error, Equatable {
    case httpStatus(Int)
    case decodingFailed
}

/// Retry pacing for the usage endpoint: 60s, then 120s, then 300s forever,
/// reset to 60s by any success.
public struct Backoff: Sendable {
    public static let steps: [TimeInterval] = [60, 120, 300]

    public private(set) var failureCount = 0

    public init() {}

    public mutating func recordSuccess() { failureCount = 0 }
    public mutating func recordFailure() { failureCount += 1 }

    public var delay: TimeInterval {
        guard failureCount > 0 else { return Self.steps[0] }
        return Self.steps[min(failureCount - 1, Self.steps.count - 1)]
    }
}

public protocol UsageProviding: Sendable {
    func fetch() async throws -> UsageSnapshot
}

public struct HTTPUsageProvider: UsageProviding {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private let credentials: any CredentialsProviding
    private let transport: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let now: @Sendable () -> Date

    public init(
        credentials: any CredentialsProviding,
        transport: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.credentials = credentials
        self.transport = transport
        self.now = now
    }

    public static func liveTransport() -> @Sendable (URLRequest) async throws -> (Data, URLResponse) {
        let session = URLSession(configuration: .ephemeral)
        return { request in try await session.data(for: request) }
    }

    public func fetch() async throws -> UsageSnapshot {
        let token = try credentials.credentials().accessToken
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport(request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UsageServiceError.httpStatus(http.statusCode)
        }
        do {
            return try UsageDecoder.snapshot(from: data, fetchedAt: now())
        } catch {
            throw UsageServiceError.decodingFailed
        }
    }
}
