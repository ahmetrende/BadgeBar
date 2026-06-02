import Foundation

/// UserDefaults keys shared between the SwiftUI settings UI (which binds via
/// `@AppStorage`) and the menu-bar renderer (which reads them each poll).
enum SettingsKeys {
    static let showCount = "settings.showCount"
    static let hideWhenNoBadge = "settings.hideWhenNoBadge"
    static let dimWhenNoBadge = "settings.dimWhenNoBadge"
    static let hideWhenAppNotRunning = "settings.hideWhenAppNotRunning"
    static let floatingAlert = "settings.floatingAlert"
    static let floatingAlertDuration = "settings.floatingAlertDuration"
}

/// Read-only accessors for the status-bar renderer. The SwiftUI side writes the
/// same keys through `@AppStorage`, and because the status bar re-renders every
/// second, changes show up without any extra observation wiring.
enum Settings {
    /// Show the numeric unread count. When off, a notification shows as a small
    /// red dot instead. Defaults to on.
    static var showCount: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.showCount) as? Bool ?? true
    }

    /// Only show an app's menu-bar icon while it has an unread badge. Defaults
    /// to off (always show the icon).
    static var hideWhenNoBadge: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.hideWhenNoBadge)
    }

    /// Dim (grey out) the icon when there's no badge, instead of hiding it.
    /// Ignored when `hideWhenNoBadge` is on. Defaults to off.
    static var dimWhenNoBadge: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.dimWhenNoBadge)
    }

    /// Hide the icon entirely while the monitored app isn't running.
    /// Defaults to off.
    static var hideWhenAppNotRunning: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.hideWhenAppNotRunning)
    }

    /// Show a floating on-screen alert when a new message arrives (works over
    /// full-screen apps). Defaults to on.
    static var floatingAlertEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.floatingAlert) as? Bool ?? true
    }

    /// How long the floating alert stays on screen, in seconds. Defaults to 4.
    static var floatingAlertDuration: Double {
        let value = UserDefaults.standard.double(forKey: SettingsKeys.floatingAlertDuration)
        return value > 0 ? value : 4
    }
}
