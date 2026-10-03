import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings
    @Published private(set) var permissionStatuses: [PermissionStatus]
    @Published var errorMessage: String?

    let audioCapabilities: AudioCapabilities

    private let persistence: PersistenceServicing
    private let launchAtLoginService: LaunchAtLoginService
    private let permissionService: PermissionServicing

    var onSettingsChanged: ((AppSettings) -> Void)?

    init(
        persistence: PersistenceServicing,
        launchAtLoginService: LaunchAtLoginService,
        permissionService: PermissionServicing,
        audioCapabilities: AudioCapabilities
    ) {
        self.persistence = persistence
        self.launchAtLoginService = launchAtLoginService
        self.permissionService = permissionService
        self.audioCapabilities = audioCapabilities

        var loadedSettings = persistence.loadSettings()
        if loadedSettings.launchAtLogin != launchAtLoginService.isEnabled {
            loadedSettings.launchAtLogin = launchAtLoginService.isEnabled
            persistence.saveSettings(loadedSettings)
        }
        self.settings = loadedSettings
        self.permissionStatuses = permissionService.statuses()
    }

    func setStartMinimized(_ value: Bool) {
        updateSettings { $0.startMinimized = value }
    }

    func setShowInactive(_ value: Bool) {
        updateSettings { $0.showInactiveAudioApplications = value }
    }

    func setRefreshInterval(_ value: TimeInterval) {
        updateSettings { $0.refreshInterval = value }
    }

    func setRestorePreviousVolumes(_ value: Bool) {
        updateSettings { $0.restorePreviousAppVolumes = value }
    }

    func setOpenAtStartup(_ value: Bool) {
        updateSettings { $0.openAtStartup = value }
    }

    func setLaunchAtLogin(_ value: Bool) {
        let oldValue = settings.launchAtLogin
        do {
            try launchAtLoginService.setEnabled(value)
            settings.launchAtLogin = value
            persistAndNotify()
            errorMessage = nil
        } catch {
            settings.launchAtLogin = oldValue
            errorMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }

    func resetSavedAppVolumes() {
        persistence.resetSavedAppVolumes()
        settings = persistence.loadSettings()
        errorMessage = nil
        onSettingsChanged?(settings)
    }

    func refreshPermissions() {
        permissionStatuses = permissionService.statuses()
    }

    private func updateSettings(_ update: (inout AppSettings) -> Void) {
        update(&settings)
        settings.normalize()
        persistAndNotify()
        errorMessage = nil
    }

    private func persistAndNotify() {
        persistence.saveSettings(settings)
        onSettingsChanged?(settings)
    }
}
