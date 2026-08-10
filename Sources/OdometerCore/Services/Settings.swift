import Foundation
import Observation

@Observable
public final class Settings {
    public static let availableSoundNames = ["Submarine", "Ping", "Glass", "Pop", "Tink"]

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        soundEnabled = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        soundName = defaults.string(forKey: Key.soundName) ?? Self.availableSoundNames[0]
        notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true

        let stored = defaults.array(forKey: Key.thresholds) as? [Double] ?? []
        thresholds = stored.isEmpty ? [80, 95] : Self.normalize(stored)

        menuBarLimit = (defaults.string(forKey: Key.menuBarLimit)
            .flatMap(LimitKind.init(rawValue:))) ?? .session
    }

    public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    public var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }

    public var soundName: String {
        didSet { defaults.set(soundName, forKey: Key.soundName) }
    }

    public var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
    }

    public var thresholds: [Double] {
        didSet {
            thresholds = Self.normalize(thresholds)
            defaults.set(thresholds, forKey: Key.thresholds)
        }
    }

    public var menuBarLimit: LimitKind {
        didSet { defaults.set(menuBarLimit.rawValue, forKey: Key.menuBarLimit) }
    }

    private static func normalize(_ values: [Double]) -> [Double] {
        Array(Set(values)).sorted()
    }

    private enum Key {
        static let launchAtLogin = "launchAtLogin"
        static let soundEnabled = "soundEnabled"
        static let soundName = "soundName"
        static let notificationsEnabled = "notificationsEnabled"
        static let thresholds = "thresholds"
        static let menuBarLimit = "menuBarLimit"
    }
}
