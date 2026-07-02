import AppKit
import SwiftUI

/// Shows a single floating alert near the top of the active screen when a new
/// message arrives. The panel floats above everything — including full-screen
/// apps, where the menu bar (and our status items) are hidden.
@MainActor
final class AlertPresenter {
    private var panel: NSPanel?
    private var hosting: NSHostingController<FloatingAlertView>?
    private var dismissTask: DispatchWorkItem?

    func show(app: MonitoredApp, badge: String) {
        guard Settings.floatingAlertEnabled else { return }

        let icon = AppIconLoader.icon(forBundleId: app.bundleId)
        let view = FloatingAlertView(icon: icon, appName: app.name, badge: badge) {
            AppLauncher.activate(bundleId: app.bundleId)
        }

        let panel = ensurePanel()
        hosting?.rootView = view
        position(panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        scheduleDismiss()
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let size = NSSize(width: 300, height: 80)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        // Let it ride along onto every Space and over full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let host = NSHostingController(
            rootView: FloatingAlertView(icon: NSImage(), appName: "", badge: "", onTap: {})
        )
        panel.contentViewController = host

        self.hosting = host
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.withMouse ?? NSScreen.main ?? NSScreen.screens.first
        // visibleFrame excludes the menu bar and the notch inset, so the alert
        // lands cleanly below the menu bar and beside the notch.
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height - 16
        ))
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + Settings.floatingAlertDuration, execute: task)
    }

    private func dismiss() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }
}

private struct FloatingAlertView: View {
    let icon: NSImage
    let appName: String
    let badge: String
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(appName.isEmpty ? " " : appName)
                    .font(.headline)
                    .lineLimit(1)
                Text("New notification")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(badge)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red, in: Capsule())
        }
        .padding(14)
        .frame(width: 300, height: 80)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.08))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private extension NSScreen {
    static var withMouse: NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
    }
}
