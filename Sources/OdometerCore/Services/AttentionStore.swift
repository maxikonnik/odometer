import Foundation

public final class AttentionStore: @unchecked Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Beacons still considered live. Anything older than `staleAfter`, or any
    /// file that no longer parses, is deleted so a crashed session cannot leave
    /// the icon blinking forever.
    public func beacons(now: Date, staleAfter: TimeInterval = 3600) throws -> [AttentionBeacon] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var live: [AttentionBeacon] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let beacon = try? decoder.decode(AttentionBeacon.self, from: data)
            else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            if now.timeIntervalSince(beacon.createdAt) > staleAfter {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            live.append(beacon)
        }
        return live.sorted { $0.createdAt < $1.createdAt }
    }

    public func clearAll() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in files where file.pathExtension == "json" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
