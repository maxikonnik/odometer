import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
public final class ThresholdNotifier {
    /// False when the user declined notifications or the system refused to
    /// register the bundle. The panel surfaces this so the toggle explains itself.
    public private(set) var isAuthorized = false

    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private var tracker = ThresholdTracker()
    /// Resolved on use, never at init: `UNUserNotificationCenter.current()`
    /// raises `bundleProxyForCurrentProcess is nil` and aborts the process when
    /// there is no app bundle, which is exactly how `swift test` runs. Deferring
    /// it keeps the notifier constructible in tests, where the authorization
    /// gate means it is never actually touched.
    @ObservationIgnored private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    public init(settings: Settings) {
        self.settings = settings
        tracker.thresholds = settings.thresholds
    }

    public func requestAuthorization() async {
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            isAuthorized = false
        }
    }

    public func process(snapshot: UsageSnapshot) {
        tracker.thresholds = settings.thresholds
        guard settings.notificationsEnabled, isAuthorized else { return }

        for limit in snapshot.limits {
            for threshold in tracker.newlyCrossed(limit) {
                deliver(limit: limit, threshold: threshold)
            }
        }
    }

    private func deliver(limit: UsageLimit, threshold: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Odometer"
        content.body = "\(limit.label): израсходовано \(Int(threshold))% лимита"
        content.sound = .default

        center.add(UNNotificationRequest(
            identifier: "\(limit.kind.rawValue)-\(Int(threshold))-\(UUID().uuidString)",
            content: content,
            trigger: nil
        ))
    }
}
