import Foundation
import Testing
@testable import OdometerCore

@Suite final class AttentionStoreTests {
    private let directory: URL
    private let store: AttentionStore
    private let now = Date(timeIntervalSince1970: 1_786_400_000)

    init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        store = AttentionStore(directory: directory)
        store.ensureDirectoryExists()
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func writeBeacon(session: String, ageSeconds: TimeInterval = 0,
                             term: String? = "Apple_Terminal") throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let created = formatter.string(from: now.addingTimeInterval(-ageSeconds))
        let termField = term.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"sessionId":"\(session)","cwd":"/Users/x/proj","termProgram":\(termField),\
        "createdAt":"\(created)"}
        """
        try json.write(
            to: directory.appendingPathComponent("\(session).json"),
            atomically: true,
            encoding: .utf8
        )
    }

    @Test func emptyDirectoryHasNoBeacons() throws {
        #expect(try store.beacons(now: now, staleAfter: 3600).isEmpty)
    }

    @Test func readsASingleBeacon() throws {
        try writeBeacon(session: "s-1")
        let beacons = try store.beacons(now: now, staleAfter: 3600)
        #expect(beacons.count == 1)
        #expect(beacons.first?.sessionId == "s-1")
        #expect(beacons.first?.termProgram == "Apple_Terminal")
    }

    @Test func readsBeaconsFromSeveralSessions() throws {
        try writeBeacon(session: "s-1")
        try writeBeacon(session: "s-2")
        #expect(try store.beacons(now: now, staleAfter: 3600).count == 2)
    }

    @Test func nullTermProgramDecodes() throws {
        try writeBeacon(session: "s-1", term: nil)
        #expect(try store.beacons(now: now, staleAfter: 3600).first?.termProgram == nil)
    }

    @Test func beaconsOlderThanTheCutoffAreSweptFromDisk() throws {
        try writeBeacon(session: "old", ageSeconds: 7200)
        try writeBeacon(session: "fresh", ageSeconds: 60)

        let beacons = try store.beacons(now: now, staleAfter: 3600)
        #expect(beacons.map(\.sessionId) == ["fresh"])
        #expect(
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent("old.json").path)
        )
    }

    @Test func corruptBeaconFileIsIgnoredAndRemoved() throws {
        try "{broken".write(
            to: directory.appendingPathComponent("bad.json"),
            atomically: true,
            encoding: .utf8
        )
        try writeBeacon(session: "good")

        #expect(try store.beacons(now: now, staleAfter: 3600).map(\.sessionId) == ["good"])
        #expect(
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent("bad.json").path)
        )
    }

    @Test func clearAllRemovesEveryBeacon() throws {
        try writeBeacon(session: "s-1")
        try writeBeacon(session: "s-2")
        store.clearAll()
        #expect(try store.beacons(now: now, staleAfter: 3600).isEmpty)
    }

    @Test func missingDirectoryIsNotAnError() throws {
        try FileManager.default.removeItem(at: directory)
        #expect(try store.beacons(now: now, staleAfter: 3600).isEmpty)
    }
}
