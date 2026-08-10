import Foundation
import Security

public struct ClaudeCredentials: Equatable, Sendable {
    public let accessToken: String
    public let expiresAt: Date?
    public let rateLimitTier: String?

    public var planBadge: String? { Self.badge(forTier: rateLimitTier) }

    private struct Payload: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            let expiresAt: Double?
            let rateLimitTier: String?
        }
        let claudeAiOauth: OAuth
    }

    public static func decode(from data: Data) throws -> ClaudeCredentials {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return ClaudeCredentials(
            accessToken: payload.claudeAiOauth.accessToken,
            expiresAt: payload.claudeAiOauth.expiresAt.map {
                Date(timeIntervalSince1970: $0 / 1000)
            },
            rateLimitTier: payload.claudeAiOauth.rateLimitTier
        )
    }

    /// Turns `default_claude_max_5x` into `Max 5×` for the panel header.
    public static func badge(forTier tier: String?) -> String? {
        guard let tier else { return nil }
        if let range = tier.range(of: #"max_\d+x"#, options: .regularExpression) {
            let digits = tier[range].filter(\.isNumber)
            return "Max \(digits)×"
        }
        if tier.contains("pro") { return "Pro" }
        return nil
    }
}

public enum KeychainError: Error, Equatable {
    case itemNotFound
    case accessDenied
    case unexpectedStatus(OSStatus)
    case malformedPayload
}

public protocol CredentialsProviding: Sendable {
    func credentials() throws -> ClaudeCredentials
}

public struct KeychainCredentialsProvider: CredentialsProviding {
    public static let service = "Claude Code-credentials"

    public init() {}

    public func credentials() throws -> ClaudeCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.malformedPayload }
            do {
                return try ClaudeCredentials.decode(from: data)
            } catch {
                throw KeychainError.malformedPayload
            }
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        case errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled:
            throw KeychainError.accessDenied
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
