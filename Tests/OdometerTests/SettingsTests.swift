import Foundation
import Testing
@testable import OdometerCore

@Suite final class SettingsTests {
    private let userDefaults: UserDefaults
    private let suiteName: String

    init() throws {
        suiteName = "odometer-tests-\(UUID().uuidString)"
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    @Test func defaults() {
        let settings = Settings(defaults: userDefaults)
        #expect(!settings.launchAtLogin)
        #expect(settings.soundEnabled)
        #expect(settings.notificationsEnabled)
        #expect(settings.thresholds == [80, 95])
        #expect(settings.menuBarLimit == .session)
        #expect(Settings.availableSoundNames.contains(settings.soundName))
    }

    @Test func valuesPersistAcrossInstances() {
        let settings = Settings(defaults: userDefaults)
        settings.soundEnabled = false
        settings.notificationsEnabled = false
        settings.thresholds = [50, 90]
        settings.menuBarLimit = .weeklyScoped
        settings.soundName = "Ping"
        settings.launchAtLogin = true

        let reloaded = Settings(defaults: userDefaults)
        #expect(!reloaded.soundEnabled)
        #expect(!reloaded.notificationsEnabled)
        #expect(reloaded.thresholds == [50, 90])
        #expect(reloaded.menuBarLimit == .weeklyScoped)
        #expect(reloaded.soundName == "Ping")
        #expect(reloaded.launchAtLogin)
    }

    @Test func unknownStoredLimitFallsBackToSession() {
        userDefaults.set("nonsense", forKey: "menuBarLimit")
        #expect(Settings(defaults: userDefaults).menuBarLimit == .session)
    }

    @Test func emptyStoredThresholdsFallBackToDefaults() {
        userDefaults.set([Double](), forKey: "thresholds")
        #expect(Settings(defaults: userDefaults).thresholds == [80, 95])
    }

    @Test func thresholdsAreStoredSortedAndDeduplicated() {
        let settings = Settings(defaults: userDefaults)
        settings.thresholds = [95, 80, 95]
        #expect(Settings(defaults: userDefaults).thresholds == [80, 95])
    }
}
