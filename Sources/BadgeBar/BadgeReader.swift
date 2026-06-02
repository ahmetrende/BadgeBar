import AppKit
import ApplicationServices

/// Reads unread-badge text from the Dock's accessibility tree.
///
/// macOS apps render their unread count onto their Dock tile, and the Dock
/// exposes it as the tile element's `AXStatusLabel`. The Accessibility API
/// can't notify us when that value changes, so we poll — but cheaply:
///
/// - Each monitored app's tile `AXUIElement` is **cached**, so a poll normally
///   costs just one attribute read per app (a single cross-process call each).
/// - A full Dock walk happens only when a cached tile is missing or has gone
///   stale (app launched/quit, tile reordered, Dock restarted).
@MainActor
final class BadgeReader {
    private let statusLabelAttribute = "AXStatusLabel" as CFString

    /// When an app has no Dock tile (closed and not kept in the Dock), don't
    /// walk the whole tree every second hunting for it — back off to roughly
    /// every few seconds. A tile that goes *stale* still re-resolves at once.
    private let missingWalkBackoff = 3
    private var ticksSinceWalk = Int.max   // force a walk on the first poll

    private var dockElement: AXUIElement?
    private var dockPID: pid_t = -1
    private var tileCache: [String: AXUIElement] = [:]   // bundleId -> Dock tile

    /// Returns `[bundleId: badgeText]` for apps that currently have a badge.
    func badges(for apps: [MonitoredApp]) -> [String: String] {
        var result: [String: String] = [:]
        var hasStale = false      // a cached tile went invalid (app quit / Dock changed)
        var hasMissing = false    // an app has no cached tile yet

        // Fast path: read each app's cached tile directly.
        for app in apps {
            if let tile = tileCache[app.bundleId] {
                let (valid, badge) = status(of: tile)
                if valid {
                    if let badge, !badge.isEmpty { result[app.bundleId] = badge }
                    continue
                }
                tileCache[app.bundleId] = nil
                hasStale = true
            } else {
                hasMissing = true
            }
        }

        let shouldWalk = hasStale || (hasMissing && ticksSinceWalk >= missingWalkBackoff)
        guard shouldWalk else {
            if hasMissing { ticksSinceWalk += 1 }
            return result
        }
        ticksSinceWalk = 0

        // Slow path (rare): one Dock walk to resolve any missing tiles.
        let tilesByTitle = walkDockTiles()
        for app in apps where tileCache[app.bundleId] == nil {
            guard let tile = app.titles.lazy.compactMap({ tilesByTitle[$0] }).first else { continue }
            tileCache[app.bundleId] = tile
            let (_, badge) = status(of: tile)
            if let badge, !badge.isEmpty { result[app.bundleId] = badge }
        }
        return result
    }

    /// Reads `AXStatusLabel`. `valid` is false only when the element itself is
    /// stale/invalid (so we know to re-resolve); a valid element with no badge
    /// returns `(true, nil)`.
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

    private func walkDockTiles() -> [String: AXUIElement] {
        guard let dock = currentDock() else { return [:] }
        var tiles: [String: AXUIElement] = [:]
        collectTiles(from: dock, depth: 0, into: &tiles)
        return tiles
    }

    private func collectTiles(from element: AXUIElement, depth: Int, into tiles: inout [String: AXUIElement]) {
        guard depth < 6 else { return }   // the Dock tree is shallow; cap as a safety net

        // Only elements that support AXStatusLabel are Dock tiles; record those
        // by title. (This also avoids recording containers like the Dock app
        // root or the item lists.)
        var statusValue: AnyObject?
        let supportsStatus = AXUIElementCopyAttributeValue(element, statusLabelAttribute, &statusValue)
        if supportsStatus == .success || supportsStatus == .noValue,
           let title = copyString(element, kAXTitleAttribute as CFString), !title.isEmpty {
            tiles[title] = element
        }

        for child in children(of: element) {
            collectTiles(from: child, depth: depth + 1, into: &tiles)
        }
    }

    private func currentDock() -> AXUIElement? {
        guard let pid = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock")
            .last?.processIdentifier
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
