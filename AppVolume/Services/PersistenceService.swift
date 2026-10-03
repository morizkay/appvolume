import Foundation

protocol PersistenceServicing: AnyObject {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
    func savedVolume(for bundleIdentifier: String) -> Double?
    func savedMute(for bundleIdentifier: String) -> Bool?
    func savedOutputDevice(for bundleIdentifier: String) -> String?
    func saveVolume(_ volume: Double, for bundleIdentifier: String)
    func saveMute(_ muted: Bool, for bundleIdentifier: String)
    func saveOutputDevice(_ deviceID: String, for bundleIdentifier: String)
    func resetSavedAppVolumes()
}

final class PersistenceService: PersistenceServicing {
    private let defaults: UserDefaults
    private let settingsKey = "appvolume.settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey),
              var settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }

        settings.normalize()
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        var normalized = settings
        normalized.normalize()
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: settingsKey)
    }

    func savedVolume(for bundleIdentifier: String) -> Double? {
        loadSettings().savedAppVolumes[bundleIdentifier]
    }

    func savedMute(for bundleIdentifier: String) -> Bool? {
        loadSettings().savedAppMutes[bundleIdentifier]
    }

    func savedOutputDevice(for bundleIdentifier: String) -> String? {
        loadSettings().savedOutputDevices[bundleIdentifier]
    }

    func saveVolume(_ volume: Double, for bundleIdentifier: String) {
        var settings = loadSettings()
        settings.savedAppVolumes[bundleIdentifier] = min(max(volume, 0), 1)
        saveSettings(settings)
    }

    func saveMute(_ muted: Bool, for bundleIdentifier: String) {
        var settings = loadSettings()
        settings.savedAppMutes[bundleIdentifier] = muted
        saveSettings(settings)
    }

    func saveOutputDevice(_ deviceID: String, for bundleIdentifier: String) {
        var settings = loadSettings()
        settings.savedOutputDevices[bundleIdentifier] = deviceID
        saveSettings(settings)
    }

    func resetSavedAppVolumes() {
        var settings = loadSettings()
        settings.savedAppVolumes.removeAll()
        settings.savedAppMutes.removeAll()
        settings.savedOutputDevices.removeAll()
        saveSettings(settings)
    }
}
