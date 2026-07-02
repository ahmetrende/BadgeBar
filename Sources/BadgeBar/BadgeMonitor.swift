import Foundation

/// Drives the once-per-second poll of the Dock and pushes fresh badge values
/// into the store. The Accessibility API can't notify us when a tile's
/// attribute changes, so polling is the pragmatic approach — a single tree
/// walk per second costs well under a millisecond.
@MainActor
final class BadgeMonitor {
    private static let interval: TimeInterval = 1.0

    private let store: AppStore
    private let reader = BadgeReader()
    private var timer: Timer?

    /// Previous badge text per bundle id, for detecting new messages.
    private var previousText: [String: String] = [:]
    /// Apps whose first observation we've already recorded. The first time we
    /// ever see an app (at launch, or when the user adds it later) we prime it
    /// silently so a pre-existing badge doesn't fire a spurious alert.
    private var primedApps: Set<String> = []

    /// Called after every poll so observers (the status bar) can refresh.
    var onTick: (() -> Void)?

    /// Called when a monitored app's badge appears or increases.
    var onNewMessage: ((MonitoredApp, String) -> Void)?

    init(store: AppStore) {
        self.store = store
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.fire()
    }

    private func tick() {
        let apps = store.monitoredApps
        let ids = Set(apps.map(\.bundleId))

        // Drop state for apps that are no longer monitored (bounded memory).
        if previousText.count > ids.count {
            previousText = previousText.filter { ids.contains($0.key) }
        }
        primedApps.formIntersection(ids)

        // Without Accessibility access nothing can be read: clear badges, let
        // the status bar surface a warning, and re-prime so regaining access
        // doesn't fire a burst of alerts.
        guard Accessibility.isTrusted else {
            for id in ids where store.badges[id] != nil { store.badges[id] = nil }
            primedApps.removeAll()
            onTick?()
            return
        }

        if !apps.isEmpty {
            let badges = reader.badges(for: apps)
            for app in apps {
                let badge = badges[app.bundleId]
                if store.badges[app.bundleId] != badge {
                    store.badges[app.bundleId] = badge   // skip no-op writes (avoids Observation churn)
                }

                let newText = badge ?? ""
                let oldText = previousText[app.bundleId] ?? ""
                previousText[app.bundleId] = newText

                // First time we ever see this app: prime silently, don't alert.
                guard primedApps.contains(app.bundleId) else {
                    primedApps.insert(app.bundleId)
                    continue
                }

                // Fire on a numeric increase, or an empty→non-empty transition.
                let isNew = !newText.isEmpty
                    && newText != oldText
                    && ((Int(newText) ?? 0) > (Int(oldText) ?? 0) || oldText.isEmpty)
                if isNew {
                    onNewMessage?(app, newText)
                }
            }
        }
        onTick?()
    }
}
