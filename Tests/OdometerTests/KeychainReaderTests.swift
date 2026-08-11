import Testing
@testable import OdometerCore

@Suite struct KeychainReaderTests {
    @Test func decodesTokenAndTier() throws {
        let data = """
        {"claudeAiOauth": {"accessToken": "tok-123", "refreshToken": "r",
         "expiresAt": 1786416892067, "subscriptionType": "max",
         "rateLimitTier": "default_claude_max_5x"}}
        """.data(using: .utf8)!
        let credentials = try ClaudeCredentials.decode(from: data)
        #expect(credentials.accessToken == "tok-123")
        #expect(credentials.rateLimitTier == "default_claude_max_5x")
        #expect(abs((credentials.expiresAt?.timeIntervalSince1970 ?? 0) - 1_786_416_892.067) < 0.01)
    }

    @Test func badgeForMaxTiers() throws {
        #expect(ClaudeCredentials.badge(forTier: "default_claude_max_5x") == "Max 5×")
        #expect(ClaudeCredentials.badge(forTier: "default_claude_max_20x") == "Max 20×")
    }

    @Test func badgeForProTier() {
        #expect(ClaudeCredentials.badge(forTier: "default_claude_pro") == "Pro")
    }

    @Test func badgeIsNilForUnknownTier() {
        #expect(ClaudeCredentials.badge(forTier: "something_else") == nil)
        #expect(ClaudeCredentials.badge(forTier: nil) == nil)
    }

    @Test func missingAccessTokenThrows() {
        let data = "{\"claudeAiOauth\": {\"refreshToken\": \"r\"}}".data(using: .utf8)!
        #expect(throws: (any Error).self) { try ClaudeCredentials.decode(from: data) }
    }

    @Test func garbageThrows() {
        let data = "not json".data(using: .utf8)!
        #expect(throws: (any Error).self) { try ClaudeCredentials.decode(from: data) }
    }
}
