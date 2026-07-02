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

    /// Pending alerts shown one after another so a burst doesn't overwrite
    /// itself. At most one entry per app (latest badge wins).
    private var queue: [(app: MonitoredApp, badge: String)] = []
    private var showing = false

    /// Whether the alert is enabled is decided by the caller (global + per-app);
    /// this just presents. Alerts are serialized so a new one never clobbers a
    /// visible one, and a stale fade-out can never hide a fresh panel.
    func show(app: MonitoredApp, badge: String) {
        queue.removeAll { $0.app.bundleId == app.bundleId }
        queue.append((app, badge))
        if !showing { presentNext() }
    }

    private func presentNext() {
        guard !queue.isEmpty else {
            showing = false
            return
        }
        showing = true
        let (app, badge) = queue.removeFirst()

        let view = FloatingAlertView(icon: AppIcons.icon(forBundleId: app.bundleId),
                                     appName: app.name,
                                     badge: badge) {
            AppLauncher.activate(bundleId: app.bundleId)
        }

        let panel = ensurePanel()
        hosting?.rootView = view
        position(panel)
        panel.orderFrontRegardless()
        if panel.alphaValue < 1 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 1
            }
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
        guard let panel else {
            showing = false
            presentNext()
            return
        }
        // If another alert is queued, hand the panel straight to it (no flicker);
        // otherwise fade out and hide.
        if !queue.isEmpty {
            presentNext()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // NSAnimationContext completions run on the main thread.
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.queue.isEmpty {
                    panel.orderOut(nil)
                    self.showing = false
                } else {
                    self.presentNext()
                }
            }
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
                Text(L.t("New notification"))
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
