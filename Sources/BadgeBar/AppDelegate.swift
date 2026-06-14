import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = AppStore()
    private var statusBar: StatusItemController!
    private var monitor: BadgeMonitor!
    private let alerts = AlertPresenter()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusItemController(store: store)
        statusBar.onConfigure = { [weak self] in self?.showSettings() }

        monitor = BadgeMonitor(store: store)
        monitor.onTick = { [weak self] in self?.statusBar.sync() }
        monitor.onNewMessage = { [weak self] app, badge in
            self?.alerts.show(app: app, badge: badge)
        }
        monitor.start()

        // Ask for Accessibility permission up front — nothing can be read
        // from the Dock without it.
        if !Accessibility.isTrusted {
            Accessibility.prompt()
        }

        // First run (or everything removed): show the picker so there is a
        // way in. Otherwise the per-app status items are the entry point.
        if store.monitoredApps.isEmpty {
            showSettings()
        }
    }

    /// Reopening the app (e.g. launching it again from Finder/Spotlight) opens
    /// the settings window. This is the way back in when the menu bar is empty
    /// because every monitored app is currently hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return true
    }

    func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(store: store))
            let window = NSWindow(contentViewController: hosting)
            window.title = "BadgeBar"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 520, height: 600))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Tear the settings window down on close so the installed-apps list and
    /// its Spotlight query don't sit in memory while we idle in the background.
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsWindow?.delegate = nil
        settingsWindow = nil
    }
}
