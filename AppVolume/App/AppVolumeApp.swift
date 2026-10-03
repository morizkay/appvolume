import SwiftUI

@main
struct AppVolumeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                viewModel: appDelegate.appState.settingsViewModel,
                capabilities: appDelegate.appState.audioService.capabilities
            )
        }
    }
}
