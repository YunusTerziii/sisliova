import Foundation
import Observation

/// Hareket, ses ve haptic tercihleri. Kapalıyken bütün bilgi metinde kalır.
@MainActor
@Observable
public final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    public var reduceMotion: Bool { didSet { defaults.set(reduceMotion, forKey: Key.motion) } }
    public var sound: Bool { didSet { defaults.set(sound, forKey: Key.sound) } }
    public var haptics: Bool { didSet { defaults.set(haptics, forKey: Key.haptics) } }

    enum Key {
        static let motion = "pref.reduceMotion"
        static let sound = "pref.sound"
        static let haptics = "pref.haptics"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reduceMotion = defaults.bool(forKey: Key.motion)
        sound = defaults.object(forKey: Key.sound) as? Bool ?? true
        haptics = defaults.object(forKey: Key.haptics) as? Bool ?? true
    }
}
