import Testing
import Foundation
@testable import OdometerCore

@Suite struct UsageDecoderTests {
    private let sample = """
    {
      "limits": [
        {"kind": "session", "group": "session", "percent": 41, "severity": "normal",
         "resets_at": "2026-08-10T23:19:59.597633+00:00", "scope": null, "is_active": true},
        {"kind": "weekly_all", "group": "weekly", "percent": 38, "severity": "normal",
         "resets_at": "2026-08-13T05:59:59.597656+00:00", "scope": null, "is_active": false},
        {"kind": "weekly_scoped", "group": "weekly", "percent": 11, "severity": "normal",
         "resets_at": "2026-08-13T05:59:59.597878+00:00",
         "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null},
         "is_active": false}
      ]
    }
    """.data(using: .utf8)!

    @Test func decodesAllThreeLimits() throws {
        let snapshot = try UsageDecoder.snapshot(from: sample, fetchedAt: Date(timeIntervalSince1970: 0))
        #expect(snapshot.limits.count == 3)
        #expect(snapshot.limit(.session)?.percent == 41)
        #expect(snapshot.limit(.weeklyAll)?.percent == 38)
        #expect(snapshot.limit(.weeklyScoped)?.percent == 11)
    }

    @Test func labelsSessionAndWeekly() throws {
        let snapshot = try UsageDecoder.snapshot(from: sample, fetchedAt: Date())
        #expect(snapshot.limit(.session)?.label == "Сессия 5 ч")
        #expect(snapshot.limit(.weeklyAll)?.label == "Неделя")
    }

    @Test func scopedLabelUsesModelDisplayName() throws {
        let snapshot = try UsageDecoder.snapshot(from: sample, fetchedAt: Date())
        #expect(snapshot.limit(.weeklyScoped)?.label == "Fable · нед.")
    }

    @Test func scopedLabelFallsBackWhenModelMissing() throws {
        let data = """
        {"limits": [{"kind": "weekly_scoped", "percent": 5, "resets_at": null,
                     "scope": null, "is_active": false}]}
        """.data(using: .utf8)!
        let snapshot = try UsageDecoder.snapshot(from: data, fetchedAt: Date())
        #expect(snapshot.limit(.weeklyScoped)?.label == "Модель · нед.")
    }

    @Test func parsesFractionalSecondsTimestamp() throws {
        let snapshot = try UsageDecoder.snapshot(from: sample, fetchedAt: Date())
        let resets = try #require(snapshot.limit(.session)?.resetsAt)
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 10
        components.hour = 23; components.minute = 19; components.second = 59
        components.timeZone = TimeZone(identifier: "UTC")
        let expected = try #require(Calendar(identifier: .gregorian).date(from: components))
        #expect(abs(resets.timeIntervalSince1970 - expected.timeIntervalSince1970) < 1)
    }

    @Test func nullResetsAtDecodesToNil() throws {
        let data = """
        {"limits": [{"kind": "session", "percent": 0, "resets_at": null, "scope": null, "is_active": true}]}
        """.data(using: .utf8)!
        let snapshot = try UsageDecoder.snapshot(from: data, fetchedAt: Date())
        #expect(snapshot.limit(.session)?.resetsAt == nil)
    }

    @Test func unknownKindIsIgnoredRatherThanThrowing() throws {
        let data = """
        {"limits": [
          {"kind": "session", "percent": 10, "resets_at": null, "scope": null, "is_active": true},
          {"kind": "some_future_limit", "percent": 90, "resets_at": null, "scope": null, "is_active": false}
        ]}
        """.data(using: .utf8)!
        let snapshot = try UsageDecoder.snapshot(from: data, fetchedAt: Date())
        #expect(snapshot.limits.count == 1)
        #expect(snapshot.limit(.session)?.percent == 10)
    }

    @Test func missingLimitsArrayThrows() {
        let data = "{\"five_hour\": {}}".data(using: .utf8)!
        #expect(throws: (any Error).self) { try UsageDecoder.snapshot(from: data, fetchedAt: Date()) }
    }
}
