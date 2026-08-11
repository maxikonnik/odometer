import Foundation

public enum ISO8601 {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// The server sends six fractional-second digits, which ISO8601DateFormatter
    /// rejects, so the fraction is stripped before parsing. Sub-second precision
    /// is irrelevant for reset times.
    public static func date(from string: String) -> Date? {
        let withoutFraction = string.replacingOccurrences(
            of: #"\.\d+"#,
            with: "",
            options: .regularExpression
        )
        return formatter.date(from: withoutFraction)
    }
}
