import Foundation

struct AppSettings: Codable, Equatable {
    static let defaultRefreshInterval: TimeInterval = 1.0
    static let refreshIntervalOptions: [TimeInterval] = [0.25, 0.5, 1.0]

    var launchAtLogin = false
    var startMinimized = true
    var showInactiveAudioApplications = false
    var refreshInterval = AppSettings.defaultRefreshInterval
    var restorePreviousAppVolumes = true
    var openAtStartup = false
    var savedAppVolumes: [String: Double] = [:]
    var savedAppMutes: [String: Bool] = [:]
    var savedOutputDevices: [String: String] = [:]

    mutating func normalize() {
        refreshInterval = Self.refreshIntervalOptions.min {
            abs($0 - refreshInterval) < abs($1 - refreshInterval)
        } ?? Self.defaultRefreshInterval
        refreshInterval = min(max(refreshInterval, 0.25), 1.0)

        savedAppVolumes = savedAppVolumes.reduce(into: [:]) { result, entry in
            let value = min(max(entry.value, 0), 1)
            result[entry.key] = value
        }
    }
}
