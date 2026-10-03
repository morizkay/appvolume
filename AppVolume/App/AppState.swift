import Foundation

@MainActor
final class AppState: ObservableObject {
    let audioService: AudioService
    let persistenceService: PersistenceServicing
    let permissionService: PermissionServicing
    let launchAtLoginService: LaunchAtLoginService
    let mainViewModel: MainViewModel
    let settingsViewModel: SettingsViewModel

    init(
        audioService: AudioService = CoreAudioService(),
        persistenceService: PersistenceServicing = PersistenceService(),
        permissionService: PermissionServicing = PermissionService(),
        launchAtLoginService: LaunchAtLoginService = SystemLaunchAtLoginService()
    ) {
        self.audioService = audioService
        self.persistenceService = persistenceService
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService

        let mainViewModel = MainViewModel(audioService: audioService, persistence: persistenceService)
        self.mainViewModel = mainViewModel
        self.settingsViewModel = SettingsViewModel(
            persistence: persistenceService,
            launchAtLoginService: launchAtLoginService,
            permissionService: permissionService,
            audioCapabilities: audioService.capabilities
        )
        self.settingsViewModel.onSettingsChanged = { [weak mainViewModel] settings in
            mainViewModel?.apply(settings: settings)
        }
    }
}
