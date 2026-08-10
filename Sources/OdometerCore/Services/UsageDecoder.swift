import Foundation

public enum UsageDecoder {
    private struct Response: Decodable {
        struct Limit: Decodable {
            struct Scope: Decodable {
                struct Model: Decodable {
                    let displayName: String?
                }
                let model: Model?
            }
            let kind: String
            let percent: Double
            let resetsAt: String?
            let isActive: Bool?
            let scope: Scope?
        }
        let limits: [Limit]
    }

    public static func snapshot(from data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(Response.self, from: data)

        let limits = response.limits.compactMap { raw -> UsageLimit? in
            guard let kind = LimitKind(rawValue: raw.kind) else { return nil }
            return UsageLimit(
                kind: kind,
                label: label(for: kind, scope: raw.scope),
                percent: raw.percent,
                resetsAt: raw.resetsAt.flatMap(ISO8601.date(from:)),
                isActive: raw.isActive ?? false
            )
        }
        return UsageSnapshot(limits: limits, fetchedAt: fetchedAt)
    }

    private static func label(for kind: LimitKind, scope: Response.Limit.Scope?) -> String {
        switch kind {
        case .session:
            return "Сессия 5 ч"
        case .weeklyAll:
            return "Неделя"
        case .weeklyScoped:
            let model = scope?.model?.displayName ?? "Модель"
            return "\(model) · нед."
        }
    }
}
