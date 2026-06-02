import AppKit

/// Shared app open/activate logic used by both the menu-bar items and the
/// floating alert.
@MainActor
enum AppLauncher {
    /// Toggle: if the app is frontmost, hide it; otherwise bring it forward
    /// (launching if needed).
    static func toggle(bundleId: String) {
        if let running = runningApp(bundleId) {
            if running.isActive {
                running.hide()
            } else {
                running.unhide()
                running.activate()
            }
            return
        }
        launch(bundleId)
    }

    /// Always bring the app to the front (launching if needed). Used when the
    /// user clicks a floating alert.
    static func activate(bundleId: String) {
        if let running = runningApp(bundleId) {
            running.unhide()
            running.activate()
            return
        }
        launch(bundleId)
    }

    private static func runningApp(_ bundleId: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    }

    private static func launch(_ bundleId: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
