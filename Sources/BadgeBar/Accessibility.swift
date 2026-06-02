import ApplicationServices

/// Thin wrapper around the Accessibility trust check. Reading the Dock's
/// badge labels requires the user to grant Accessibility permission in
/// System Settings → Privacy & Security → Accessibility.
enum Accessibility {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system prompt that deep-links the user to the
    /// Accessibility permission pane.
    static func prompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
