import AppKit

// BadgeBar is a menu-bar agent app: no Dock icon, no main window.
// Bootstrapped programmatically so we can manage a dynamic number of
// per-app status items (one per monitored app), which SwiftUI's
// MenuBarExtra cannot do today.
// Top-level code in main.swift runs on the main thread at process start, but
// the compiler treats it as non-isolated — assert main-actor isolation so we
// can touch the main-actor types below. `app.run()` blocks for the app's whole
// lifetime, so `delegate` stays retained (NSApplication.delegate is weak).
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    let app = NSApplication.shared
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
