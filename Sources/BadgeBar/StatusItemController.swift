import AppKit

/// Owns the menu-bar status items: one per monitored app, plus a fallback
/// "gear" item when nothing is monitored so the picker stays reachable.
///
/// Left click opens the app. Right click (or Option-click) shows a small menu.
@MainActor
final class StatusItemController: NSObject {
    private let store: AppStore

    /// Invoked when the user asks to open the configuration window.
    var onConfigure: (() -> Void)?

    private var items: [String: NSStatusItem] = [:]   // bundleId -> item
    private var appForButton: [ObjectIdentifier: MonitoredApp] = [:]
    private var iconCache: [String: NSImage] = [:]
    private var lastRenderKey: [String: String] = [:]   // bundleId -> rendered state
    private var controlItem: NSStatusItem?
    private var controlWarning = false
    private let runningApps = RunningApps()

    init(store: AppStore) {
        self.store = store
        super.init()
    }

    /// Reconcile the live status items with the store and refresh their badges.
    func sync() {
        let apps = store.monitoredApps
        let wantedIds = Set(apps.map(\.bundleId))

        // Remove items for apps no longer monitored.
        for (bundleId, item) in items where !wantedIds.contains(bundleId) {
            NSStatusBar.system.removeStatusItem(item)
            if let button = item.button {
                appForButton[ObjectIdentifier(button)] = nil
            }
            items[bundleId] = nil
            lastRenderKey[bundleId] = nil
            iconCache[bundleId] = nil
        }

        // Add items for newly monitored apps.
        for app in apps where items[app.bundleId] == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.target = self
                button.action = #selector(handleClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                appForButton[ObjectIdentifier(button)] = app
            }
            items[app.bundleId] = item
        }

        // Refresh each item's rendered icon + badge, applying display settings.
        let showCount = Settings.showCount
        let hideWhenNoBadge = Settings.hideWhenNoBadge
        let dimWhenNoBadge = Settings.dimWhenNoBadge
        let hideWhenAppNotRunning = Settings.hideWhenAppNotRunning

        for app in apps {
            guard let item = items[app.bundleId], let button = item.button else { continue }
            let badge = store.badges[app.bundleId]
            let hasBadge = !(badge ?? "").isEmpty

            let hiddenByBadge = hideWhenNoBadge && !hasBadge
            let hiddenByRunning = hideWhenAppNotRunning && !runningApps.contains(app.bundleId)
            if hiddenByBadge || hiddenByRunning {
                if item.isVisible { item.isVisible = false }
                continue
            }

            if !item.isVisible { item.isVisible = true }

            // Only redraw when the displayed state actually changed — the badge
            // is unchanged on the vast majority of 1 Hz polls.
            let key = "\(badge ?? "")|\(showCount ? 1 : 0)|\(dimWhenNoBadge ? 1 : 0)"
            if lastRenderKey[app.bundleId] != key {
                lastRenderKey[app.bundleId] = key
                button.image = BadgeIcon.render(appIcon: icon(for: app),
                                                badge: badge,
                                                showsCount: showCount,
                                                dimWhenEmpty: dimWhenNoBadge)
                button.toolTip = hasBadge ? "\(app.name) — \(badge!)" : app.name
            }
        }

        // Show the BadgeBar icon when Accessibility access is missing (a
        // warning the user must act on), when the user opted in, or when
        // nothing is configured yet (so a first-run user always has a way in).
        // Otherwise the menu bar stays clean even with no current badge.
        let trusted = Accessibility.isTrusted
        syncControlItem(show: !trusted || Settings.showControlIcon || apps.isEmpty,
                        warning: !trusted)
    }

    // MARK: - Fallback control item

    private func syncControlItem(show: Bool, warning: Bool) {
        guard show else {
            if let controlItem {
                NSStatusBar.system.removeStatusItem(controlItem)
                self.controlItem = nil
            }
            return
        }

        if controlItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.target = self
                button.action = #selector(handleControlClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            controlItem = item
        }

        guard let button = controlItem?.button else { return }
        if controlWarning != warning || button.image == nil {
            controlWarning = warning
            if warning {
                button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                       accessibilityDescription: "Accessibility access required")
                button.toolTip = "BadgeBar needs Accessibility access — click to grant"
            } else {
                button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "BadgeBar")
                button.toolTip = "BadgeBar — click to configure, right-click for menu"
            }
        }
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let app = appForButton[ObjectIdentifier(sender)] else { return }

        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
        let isOptionClick = event?.modifierFlags.contains(.option) ?? false

        if isRightClick || isOptionClick {
            showMenu(for: app, from: sender)
        } else {
            open(app)
        }
    }

    @objc private func openConfigure() {
        onConfigure?()
    }

    @objc private func handleControlClick(_ sender: NSStatusBarButton) {
        // In the warning state the icon's whole job is to fix the permission.
        if controlWarning {
            Accessibility.prompt()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            return
        }

        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
        let isOptionClick = event?.modifierFlags.contains(.option) ?? false
        if isRightClick || isOptionClick {
            showControlMenu(from: sender)
        } else {
            onConfigure?()
        }
    }

    private func showControlMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let configure = NSMenuItem(title: "Configure…", action: #selector(openConfigure), keyEquivalent: ",")
        configure.target = self
        menu.addItem(configure)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit BadgeBar", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func menuRemove(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }
        store.remove(bundleId)
        sync()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    private func showMenu(for app: MonitoredApp, from button: NSStatusBarButton) {
        let menu = NSMenu()

        let configure = NSMenuItem(title: "Configure…", action: #selector(openConfigure), keyEquivalent: ",")
        configure.target = self
        menu.addItem(configure)

        let remove = NSMenuItem(title: "Stop monitoring \(app.name)", action: #selector(menuRemove(_:)), keyEquivalent: "")
        remove.target = self
        remove.representedObject = app.bundleId
        menu.addItem(remove)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit BadgeBar", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 4),
                   in: button)
    }

    private func open(_ app: MonitoredApp) {
        AppLauncher.toggle(bundleId: app.bundleId)
    }

    private func icon(for app: MonitoredApp) -> NSImage {
        if let cached = iconCache[app.bundleId] {
            return cached
        }
        let image: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleId) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        iconCache[app.bundleId] = image
        return image
    }
}
