import Foundation

/// An app the user has chosen to mirror into the menu bar.
///
/// `titles` are the candidate strings to match against a Dock tile's
/// `AXTitle`. We capture several (display name, CFBundleName, …) because the
/// Dock tooltip name doesn't always equal any single Info.plist key.
struct MonitoredApp: Codable, Identifiable, Equatable, Hashable {
    let bundleId: String
    let name: String
    let titles: [String]

    /// Per-app overrides. `nil` means "use the global setting". Optional so old
    /// persisted JSON (without these keys) decodes cleanly to nil.
    var showCountOverride: Bool?
    var alertOverride: Bool?

    var id: String { bundleId }

    /// Effective "show unread count" for this app, given the global default.
    func showsCount(default globalDefault: Bool) -> Bool {
        showCountOverride ?? globalDefault
    }

    /// Effective "floating alert" for this app, given the global default.
    func alerts(default globalDefault: Bool) -> Bool {
        alertOverride ?? globalDefault
    }
}

@Observable
@MainActor
final class AppStore {
    /// Apps the user is monitoring, in display order. Persisted to UserDefaults.
    private(set) var monitoredApps: [MonitoredApp] = []

    /// Latest badge text keyed by bundle id. Empty/missing means "no badge".
    var badges: [String: String] = [:]

    private let storageKey = "BadgeBar.monitoredApps.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let apps = try? JSONDecoder().decode([MonitoredApp].self, from: data) {
            monitoredApps = apps
        }
    }

    func isMonitored(_ bundleId: String) -> Bool {
        monitoredApps.contains { $0.bundleId == bundleId }
    }

    func add(_ app: MonitoredApp) {
        guard !isMonitored(app.bundleId) else { return }
        monitoredApps.append(app)
        persist()
    }

    func remove(_ bundleId: String) {
        monitoredApps.removeAll { $0.bundleId == bundleId }
        badges[bundleId] = nil
        persist()
    }

    /// Replace a monitored app in place (e.g. after editing per-app overrides).
    func update(_ app: MonitoredApp) {
        guard let index = monitoredApps.firstIndex(where: { $0.bundleId == app.bundleId }) else { return }
        monitoredApps[index] = app
        persist()
    }

    /// Reorder monitored apps (drag-to-reorder in Settings).
    func move(fromOffsets: IndexSet, toOffset: Int) {
        monitoredApps.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(monitoredApps) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
