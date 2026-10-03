import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState: AppState
    private var menuBarController: MenuBarController?

    override init() {
        appState = AppState()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(appState: appState)
        appState.mainViewModel.start()

        if !appState.settingsViewModel.settings.startMinimized,
           appState.settingsViewModel.settings.openAtStartup {
            menuBarController?.showMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
