import AppKit

/// One installed application, as shown in the picker.
struct AppInfo: Identifiable, Hashable {
    let bundleId: String
    let path: String
    let name: String

    var id: String { bundleId }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    /// The candidate strings a Dock tile might use as its `AXTitle`.
    var dockTitles: [String] {
        var titles = [name]
        if let bundle = Bundle(path: path) {
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                if let value = bundle.object(forInfoDictionaryKey: key) as? String {
                    titles.append(value)
                }
            }
        }
        return Array(Set(titles)).filter { !$0.isEmpty }
    }

    func toMonitored() -> MonitoredApp {
        MonitoredApp(bundleId: bundleId, name: name, titles: dockTitles)
    }
}

/// Discovers installed applications via Spotlight metadata.
@Observable
@MainActor
final class InstalledApps {
    private(set) var apps: [AppInfo] = []

    @ObservationIgnored private let query = NSMetadataQuery()

    deinit {
        NotificationCenter.default.removeObserver(self)
        query.stop()
    }

    func load() {
        guard !query.isStarted else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryFinished(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        query.predicate = NSPredicate(format: "kMDItemContentType == 'com.apple.application-bundle'")
        query.start()
    }

    @objc private func queryFinished(_ notification: Notification) {
        var byBundle: [String: AppInfo] = [:]
        for case let item as NSMetadataItem in query.results {
            guard let bundleId = item.value(forAttribute: kMDItemCFBundleIdentifier as String) as? String,
                  let path = item.value(forAttribute: kMDItemPath as String) as? String,
                  let name = item.value(forAttribute: kMDItemDisplayName as String) as? String
            else { continue }

            byBundle[bundleId] = AppInfo(
                bundleId: bundleId,
                path: path,
                name: name.replacingOccurrences(of: ".app", with: "")
            )
        }
        apps = Array(byBundle.values)
        query.stop()
    }
}
