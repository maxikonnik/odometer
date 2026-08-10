import Foundation
import Observation

@Observable
public final class AttentionService {
    public private(set) var beacons: [AttentionBeacon] = []

    public var isBlinking: Bool { !beacons.isEmpty }

    /// Called once per newly seen beacon so the app can play a sound. Never
    /// fires for beacons that were already present.
    @ObservationIgnored public var newBeaconHandler: ((AttentionBeacon) -> Void)?

    @ObservationIgnored private let store: AttentionStore
    @ObservationIgnored private var source: DispatchSourceFileSystemObject?
    @ObservationIgnored private var descriptor: CInt = -1
    @ObservationIgnored private var announced: Set<String> = []

    public init(store: AttentionStore) {
        self.store = store
    }

    public func start() {
        store.ensureDirectoryExists()
        refresh(now: Date())

        descriptor = open(store.directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.refresh(now: Date())
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }
        source.resume()
        self.source = source
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    public func refresh(now: Date) {
        let live = (try? store.beacons(now: now)) ?? []
        let liveIds = Set(live.map(\.sessionId))

        for beacon in live where !announced.contains(beacon.sessionId) {
            newBeaconHandler?(beacon)
        }
        announced = liveIds
        beacons = live
    }

    public func clear() {
        store.clearAll()
        announced = []
        beacons = []
    }
}
