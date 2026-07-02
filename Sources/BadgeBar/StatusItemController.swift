import AppKit

/// Owns the menu-bar status items: one per monitored app, plus a fallback icon
/// (for the empty state, the "always show" option, or an Accessibility warning).
///
/// Left click toggles the app. Right click (or Option-click) shows a menu.
@MainActor
final class StatusItemController: NSObject {
    private let store: AppStore

    /// Invoked when the user asks to open the configuration window.
    var onConfigure: (() -> Void)?

    private var items: [String: NSStatusItem] = [:]        // bundleId -> item
    private var appForButton: [ObjectIdentifier: String] = [:]  // button -> bundleId
    private var lastRenderKey: [String: String] = [:]      // bundleId -> rendered state
    private var orderedIds: [String] = []                  // creation order of per-app items
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
        let desiredOrder = apps.map(\.bundleId)
        let wantedIds = Set(desiredOrder)

        // If the relative order of still-present items changed (drag-to-reorder),
        // rebuild all per-app items so the menu bar follows the new order.
        let prevCommon = orderedIds.filter { wantedIds.contains($0) }
        let newCommon = desiredOrder.filter { orderedIds.contains($0) }
        if prevCommon != newCommon {
            for (_, item) in items {
                NSStatusBar.system.removeStatusItem(item)
                if let button = item.button { appForButton[ObjectIdentifier(button)] = nil }
            }
            items.removeAll()
            lastRenderKey.removeAll()
        }

        // Remove items for apps no longer monitored.
        for (bundleId, item) in items where !wantedIds.contains(bundleId) {
            NSStatusBar.system.removeStatusItem(item)
            if let button = item.button { appForButton[ObjectIdentifier(button)] = nil }
            items[bundleId] = nil
            lastRenderKey[bundleId] = nil
        }

        // Add items for newly monitored apps (in order).
        for app in apps where items[app.bundleId] == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.target = self
                button.action = #selector(handleClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                appForButton[ObjectIdentifier(button)] = app.bundleId
            }
            items[app.bundleId] = item
        }
        orderedIds = desiredOrder

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

            let showsCount = app.showsCount(default: showCount)
            // Only redraw when the displayed state actually changed.
            let key = "\(badge ?? "")|\(showsCount ? 1 : 0)|\(dimWhenNoBadge ? 1 : 0)"
            if lastRenderKey[app.bundleId] != key {
                lastRenderKey[app.bundleId] = key
                button.image = BadgeIcon.render(appIcon: AppIcons.icon(forBundleId: app.bundleId),
                                                badge: badge,
                                                showsCount: showsCount,
                                                dimWhenEmpty: dimWhenNoBadge)
                button.toolTip = hasBadge ? "\(app.name) — \(badge!)" : app.name
            }
        }

        // Show the BadgeBar icon when Accessibility access is missing (a warning
        // the user must act on), when the user opted in, or when nothing is
        // configured yet (so a first-run user always has a way in).
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
                button.toolTip = L.t("BadgeBar needs Accessibility access — click to grant")
            } else {
                button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "BadgeBar")
                button.toolTip = L.t("BadgeBar — click to configure, right-click for menu")
            }
        }
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let bundleId = appForButton[ObjectIdentifier(sender)],
              let app = store.monitoredApps.first(where: { $0.bundleId == bundleId }) else { return }

        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
        let isOptionClick = event?.modifierFlags.contains(.option) ?? false

        if isRightClick || isOptionClick {
            showMenu(for: app, from: sender)
        } else {
            AppLauncher.toggle(bundleId: app.bundleId)
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

    @objc private func menuRemove(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }
        store.remove(bundleId)
        sync()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    @objc private func toggleShowCount(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              var app = store.monitoredApps.first(where: { $0.bundleId == id }) else { return }
        app.showCountOverride = !app.showsCount(default: Settings.showCount)
        store.update(app)
        lastRenderKey[id] = nil
        sync()
    }

    @objc private func toggleAlert(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              var app = store.monitoredApps.first(where: { $0.bundleId == id }) else { return }
        app.alertOverride = !app.alerts(default: Settings.floatingAlertEnabled)
        store.update(app)
        sync()
    }

    @objc private func resetOverrides(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              var app = store.monitoredApps.first(where: { $0.bundleId == id }) else { return }
        app.showCountOverride = nil
        app.alertOverride = nil
        store.update(app)
        lastRenderKey[id] = nil
        sync()
    }

    @objc private func checkForUpdates() {
        Task { [weak self] in
            let result = await UpdateChecker.check()
            self?.presentUpdateResult(result)
        }
    }

    private func presentUpdateResult(_ result: UpdateChecker.Result?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()

        guard let result else {
            alert.messageText = L.t("Couldn't check for updates")
            alert.informativeText = L.t("Please try again later.")
            alert.addButton(withTitle: L.t("OK"))
            alert.runModal()
            return
        }

        if result.hasUpdate {
            alert.messageText = L.t("Update available")
            alert.informativeText = "BadgeBar \(result.latest)  (\(result.current))"
            alert.addButton(withTitle: L.t("Download"))
            alert.addButton(withTitle: L.t("Later"))
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(result.url)
            }
        } else {
            alert.messageText = L.t("You're up to date")
            alert.informativeText = L.t("BadgeBar %@ is the latest version.", result.current)
            alert.addButton(withTitle: L.t("OK"))
            alert.runModal()
        }
    }

    // MARK: - Menus

    private func showMenu(for app: MonitoredApp, from button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(item(L.t("Configure…"), #selector(openConfigure), key: ","))

        // Per-app overrides submenu.
        let thisApp = NSMenuItem(title: L.t("This app"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let showCount = item(L.t("Show unread count"), #selector(toggleShowCount(_:)), represented: app.bundleId)
        showCount.state = app.showsCount(default: Settings.showCount) ? .on : .off
        sub.addItem(showCount)
        let alert = item(L.t("Show a floating alert on new messages"), #selector(toggleAlert(_:)), represented: app.bundleId)
        alert.state = app.alerts(default: Settings.floatingAlertEnabled) ? .on : .off
        sub.addItem(alert)
        sub.addItem(.separator())
        sub.addItem(item(L.t("Reset to defaults"), #selector(resetOverrides(_:)), represented: app.bundleId))
        thisApp.submenu = sub
        menu.addItem(thisApp)

        menu.addItem(item(L.t("Stop monitoring %@", app.name), #selector(menuRemove(_:)), represented: app.bundleId))

        menu.addItem(.separator())
        menu.addItem(item(L.t("Check for Updates…"), #selector(checkForUpdates)))
        menu.addItem(.separator())
        menu.addItem(item(L.t("Quit BadgeBar"), #selector(menuQuit), key: "q"))

        popUp(menu, from: button)
    }

    private func showControlMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(item(L.t("Configure…"), #selector(openConfigure), key: ","))
        menu.addItem(item(L.t("Check for Updates…"), #selector(checkForUpdates)))
        menu.addItem(.separator())
        menu.addItem(item(L.t("Quit BadgeBar"), #selector(menuQuit), key: "q"))
        popUp(menu, from: button)
    }

    private func item(_ title: String, _ action: Selector, key: String = "", represented: Any? = nil) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        menuItem.representedObject = represented
        return menuItem
    }

    private func popUp(_ menu: NSMenu, from button: NSStatusBarButton) {
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }
}
