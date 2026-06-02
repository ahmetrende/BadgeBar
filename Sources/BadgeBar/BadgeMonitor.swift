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
    /// Skip alerts on the very first poll so existing badges don't all fire.
    private var primed = false

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

                // Fire on a numeric increase, or an empty→non-empty transition.
                let isNew = !newText.isEmpty
                    && newText != oldText
                    && ((Int(newText) ?? 0) > (Int(oldText) ?? 0) || oldText.isEmpty)
                if primed && isNew {
                    onNewMessage?(app, newText)
                }
            }
            primed = true
        }
        onTick?()
    }
}
