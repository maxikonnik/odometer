import Foundation
import Testing
@testable import OdometerCore

private struct StubCredentials: CredentialsProviding {
    var token = "tok-abc"
    func credentials() throws -> ClaudeCredentials {
        ClaudeCredentials(accessToken: token, expiresAt: nil, rateLimitTier: nil)
    }
}

private struct FailingCredentials: CredentialsProviding {
    func credentials() throws -> ClaudeCredentials { throw KeychainError.itemNotFound }
}

@Suite struct BackoffTests {
    @Test func delayGrowsThenSaturates() {
        var backoff = Backoff()
        #expect(backoff.delay == 60)
        backoff.recordFailure()
        #expect(backoff.delay == 60)
        backoff.recordFailure()
        #expect(backoff.delay == 120)
        backoff.recordFailure()
        #expect(backoff.delay == 300)
        backoff.recordFailure()
        #expect(backoff.delay == 300)
    }

    @Test func successResetsDelay() {
        var backoff = Backoff()
        backoff.recordFailure()
        backoff.recordFailure()
        backoff.recordSuccess()
        #expect(backoff.delay == 60)
    }
}

@Suite struct HTTPUsageProviderTests {
    private func response(_ status: Int) -> URLResponse {
        HTTPURLResponse(
            url: HTTPUsageProvider.endpoint,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private let body = """
    {"limits": [{"kind": "session", "percent": 41, "resets_at": null,
                 "scope": null, "is_active": true}]}
    """.data(using: .utf8)!

    @Test func sendsBearerTokenToEndpoint() async throws {
        let captured = Captured()
        let provider = HTTPUsageProvider(
            credentials: StubCredentials(),
            transport: { request in
                await captured.set(request)
                return (self.body, self.response(200))
            },
            now: { Date(timeIntervalSince1970: 100) }
        )
        _ = try await provider.fetch()
        let request = await captured.value
        #expect(request?.url == HTTPUsageProvider.endpoint)
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer tok-abc")
    }

    @Test func stampsFetchedAt() async throws {
        let provider = HTTPUsageProvider(
            credentials: StubCredentials(),
            transport: { _ in (self.body, self.response(200)) },
            now: { Date(timeIntervalSince1970: 4242) }
        )
        let snapshot = try await provider.fetch()
        #expect(snapshot.fetchedAt == Date(timeIntervalSince1970: 4242))
        #expect(snapshot.limit(.session)?.percent == 41)
    }

    @Test func nonSuccessStatusThrows() async {
        let provider = HTTPUsageProvider(
            credentials: StubCredentials(),
            transport: { _ in (Data(), self.response(429)) },
            now: { Date() }
        )
        do {
            _ = try await provider.fetch()
            Issue.record("expected throw")
        } catch let error as UsageServiceError {
            #expect(error == .httpStatus(429))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func unparseableBodyThrowsDecodingFailed() async {
        let provider = HTTPUsageProvider(
            credentials: StubCredentials(),
            transport: { _ in ("{}".data(using: .utf8)!, self.response(200)) },
            now: { Date() }
        )
        do {
            _ = try await provider.fetch()
            Issue.record("expected throw")
        } catch let error as UsageServiceError {
            #expect(error == .decodingFailed)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func credentialFailurePropagates() async {
        let provider = HTTPUsageProvider(
            credentials: FailingCredentials(),
            transport: { _ in (Data(), self.response(200)) },
            now: { Date() }
        )
        do {
            _ = try await provider.fetch()
            Issue.record("expected throw")
        } catch let error as KeychainError {
            #expect(error == .itemNotFound)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

private actor Captured {
    var value: URLRequest?
    func set(_ request: URLRequest) { value = request }
}
