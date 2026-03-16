import Foundation

struct AppSettings: Codable {
    var appearance: AppAppearance = .system
    var accentPalette: AppAccentPalette = .mint
    var autoLockInterval: Double = 60
    var biometricUnlockEnabled = true
    var clearClipboardEnabled = true
    var prefersSymbols = true
    var prefersNumbers = true
}

struct AppSettingsStore {
    private let key = "Latch.AppSettings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else {
            return AppSettings()
        }

        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
