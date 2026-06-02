import AppKit

/// Maintains the set of running apps' bundle identifiers, updated via
/// workspace launch/terminate notifications instead of being enumerated on
/// every poll. Lets the status bar answer "is this app running?" for free.
@MainActor
final class RunningApps {
    private(set) var bundleIds: Set<String> = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(refresh),
                           name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(refresh),
                           name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    func contains(_ bundleId: String) -> Bool {
        bundleIds.contains(bundleId)
    }

    @objc private func refresh() {
        bundleIds = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }
}
