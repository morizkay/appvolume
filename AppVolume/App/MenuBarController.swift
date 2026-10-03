import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let appState: AppState
    private var mainWindow: NSWindow?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "speaker.wave.2.fill",
                accessibilityDescription: "AppVolume"
            )
            button.image?.isTemplate = true
            button.toolTip = "AppVolume"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 430, height: 600)
        popover.contentViewController = NSHostingController(
            rootView: MainView(
                viewModel: appState.mainViewModel,
                onOpenMainWindow: { [weak self] in self?.showMainWindow() },
                onOpenSettings: { [weak self] in self?.showSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func showMainWindow() {
        popover.performClose(nil)

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: MainView(
                viewModel: appState.mainViewModel,
                onOpenMainWindow: nil,
                onOpenSettings: { [weak self] in self?.showSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "AppVolume"
        window.setContentSize(NSSize(width: 620, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === mainWindow else { return }
        mainWindow = nil
    }
}
