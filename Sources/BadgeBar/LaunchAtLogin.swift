import ServiceManagement

/// Registers/unregisters BadgeBar as a login item using the modern
/// ServiceManagement API (macOS 13+). No helper bundle required.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("BadgeBar: launch-at-login update failed: \(error.localizedDescription)")
            return false
        }
    }
}
