import AppKit
import ApplicationServices

/// Reads unread-badge text from the Dock's accessibility tree.
///
/// macOS apps render their unread count onto their Dock tile, exposed as the
/// tile's `AXStatusLabel`. The API can't notify us on changes, so we poll — but
/// cheaply: each monitored app's tile `AXUIElement` is cached, so a poll
/// normally costs one attribute read per app. A full Dock walk happens only
/// when a cached tile is stale, or when a *running* app has no cached tile yet.
@MainActor
final class BadgeReader {
    private let statusLabelAttribute = "AXStatusLabel" as CFString

    /// Rate-limit walks triggered purely by a running-but-unresolved app.
    private let missingWalkBackoff = 3
    private var ticksSinceWalk = Int.max   // force a walk on the first poll

    private var dockElement: AXUIElement?
    private var dockPID: pid_t = -1
    private var tileCache: [String: AXUIElement] = [:]   // bundleId -> Dock tile

    /// Returns `[bundleId: badgeText]` for apps that currently have a badge.
    func badges(for apps: [MonitoredApp]) -> [String: String] {
        // Drop cached tiles for apps no longer monitored (bounded memory).
        let ids = Set(apps.map(\.bundleId))
        if tileCache.count > ids.count {
            tileCache = tileCache.filter { ids.contains($0.key) }
        }

        var result: [String: String] = [:]
        var hasStale = false
        var hasMissing = false   // running app with no resolved tile — worth a walk

        for app in apps {
            if let tile = tileCache[app.bundleId] {
                let (valid, badge) = status(of: tile)
                if valid {
                    if let badge, !badge.isEmpty { result[app.bundleId] = badge }
                    continue
                }
                tileCache[app.bundleId] = nil
                hasStale = true
            }
            // Only a running app is guaranteed a live Dock tile. Don't walk the
            // whole tree hunting for an app that isn't running (it has no live
            // badge anyway) — that was a perpetual once-every-few-seconds walk.
            if isRunning(app.bundleId) {
                hasMissing = true
            }
        }

        let shouldWalk = hasStale || (hasMissing && ticksSinceWalk >= missingWalkBackoff)
        guard shouldWalk else {
            if hasMissing { ticksSinceWalk += 1 }
            return result
        }
        ticksSinceWalk = 0

        let scan = walkDock()
        for app in apps where tileCache[app.bundleId] == nil {
            guard let tile = resolveTile(for: app, in: scan) else { continue }
            tileCache[app.bundleId] = tile
            let (_, badge) = status(of: tile)
            if let badge, !badge.isEmpty { result[app.bundleId] = badge }
        }
        return result
    }

    private func resolveTile(for app: MonitoredApp, in scan: DockScan) -> AXUIElement? {
        // Prefer an exact bundle-id match (robust when two apps share a title).
        if let byId = scan.byBundleId[app.bundleId] {
            return byId
        }
        return app.titles.lazy.compactMap { scan.byTitle[$0] }.first
    }

    private func isRunning(_ bundleId: String) -> Bool {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleId)
            .contains { !$0.isTerminated }
    }

    /// Reads `AXStatusLabel`. `valid` is false only when the element itself is
    /// stale/invalid; a valid element with no badge returns `(true, nil)`.
    private func status(of element: AXUIElement) -> (valid: Bool, badge: String?) {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, statusLabelAttribute, &value)
        switch error {
        case .success, .noValue, .attributeUnsupported:
            return (true, value as? String)
        default:
            return (false, nil)
        }
    }

    // MARK: - Dock walk (slow path)

    private struct DockScan {
        var byBundleId: [String: AXUIElement] = [:]
        var byTitle: [String: AXUIElement] = [:]
    }

    private func walkDock() -> DockScan {
        guard let dock = currentDock() else { return DockScan() }
        var scan = DockScan()
        collectTiles(from: dock, depth: 0, into: &scan)
        return scan
    }

    private func collectTiles(from element: AXUIElement, depth: Int, into scan: inout DockScan) {
        guard depth < 6 else { return }   // the Dock tree is shallow; cap as a safety net

        // Only elements that support AXStatusLabel are Dock tiles.
        var statusValue: AnyObject?
        let support = AXUIElementCopyAttributeValue(element, statusLabelAttribute, &statusValue)
        if support == .success || support == .noValue {
            if let bundleId = bundleId(of: element) {
                scan.byBundleId[bundleId] = element
            }
            if let title = copyString(element, kAXTitleAttribute as CFString), !title.isEmpty {
                scan.byTitle[title] = element
            }
        }

        for child in children(of: element) {
            collectTiles(from: child, depth: depth + 1, into: &scan)
        }
    }

    /// A Dock tile often exposes the app's file URL; resolve its bundle id so we
    /// can match by identity rather than by (possibly shared) display name.
    private func bundleId(of element: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value) == .success,
              let url = value as? URL else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    private func currentDock() -> AXUIElement? {
        // Prefer a live (non-terminated) Dock process; ".last" was arbitrary.
        guard let pid = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock")
            .first(where: { !$0.isTerminated })?
            .processIdentifier
        else { return nil }

        if dockElement == nil || dockPID != pid {
            dockPID = pid
            dockElement = AXUIElementCreateApplication(pid)
            tileCache.removeAll()   // Dock restarted — drop stale tiles
        }
        return dockElement
    }

    private func copyString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else { return [] }
        return elements
    }
}
