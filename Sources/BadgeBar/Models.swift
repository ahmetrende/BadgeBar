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

    var id: String { bundleId }
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

    private func persist() {
        if let data = try? JSONEncoder().encode(monitoredApps) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
