import Foundation

/// Drives the once-per-second poll of the Dock and pushes fresh badge values
/// into the store. The Accessibility API can't notify us when a tile's
/// attribute changes, so polling is the pragmatic approach — a single tree
/// walk per second costs well under a millisecond.
@MainActor
final class BadgeMonitor {
    private let store: AppStore
    private let reader = BadgeReader()
    private var timer: Timer?
    private var currentInterval: TimeInterval = 0

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
        scheduleTimer()
        timer?.fire()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        currentInterval = Settings.pollInterval
        timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Decides whether a badge change should raise a "new message" alert.
    /// Fires on first appearance, a numeric increase (handles "9+"), or any
    /// change involving non-numeric text. Pure so it's unit-testable.
    nonisolated static func isNewMessage(old: String, new: String) -> Bool {
        guard !new.isEmpty, new != old else { return false }
        if old.isEmpty { return true }
        if let newN = leadingInt(new), let oldN = leadingInt(old) {
            return newN > oldN
        }
        return true
    }

    nonisolated private static func leadingInt(_ text: String) -> Int? {
        let digits = text.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
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

                if Self.isNewMessage(old: oldText, new: newText),
                   app.alerts(default: Settings.floatingAlertEnabled) {
                    onNewMessage?(app, newText)
                }
            }
        }
        onTick?()

        // Re-arm the timer if the user changed the poll interval.
        if Settings.pollInterval != currentInterval {
            scheduleTimer()
        }
    }
}
