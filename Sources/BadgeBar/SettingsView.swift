import SwiftUI

/// The configuration window: an "Apps" tab to pick which apps to mirror, and a
/// "Settings" tab for preferences like launch-at-login.
struct SettingsView: View {
    @Bindable var store: AppStore

    var body: some View {
        TabView {
            AppsTab(store: store)
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }

            PreferencesTab()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .frame(width: 540, height: 600)
    }
}

// MARK: - Apps tab

private struct AppsTab: View {
    @Bindable var store: AppStore
    @State private var installed = InstalledApps()
    @State private var search = ""

    private var filteredApps: [AppInfo] {
        let sorted = installed.apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        guard !search.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !store.monitoredApps.isEmpty {
                monitoredStrip
                Divider()
            }
            searchField
            appList
        }
        .onAppear {
            installed.load()
            if !Accessibility.isTrusted { Accessibility.prompt() }
        }
    }

    private var monitoredStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monitoring \(store.monitoredApps.count)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.monitoredApps) { app in
                        chip(for: app)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 12)
    }

    private func chip(for app: MonitoredApp) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: AppIconLoader.icon(forBundleId: app.bundleId))
                .resizable()
                .frame(width: 18, height: 18)
            Text(app.name)
                .font(.callout)
            Button {
                store.remove(app.bundleId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search apps…", text: $search)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var appList: some View {
        List(filteredApps) { app in
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                Text(app.name)
                Spacer()
                if store.isMonitored(app.bundleId) {
                    Button("Remove") { store.remove(app.bundleId) }
                        .buttonStyle(.bordered)
                } else {
                    Button("Add") { store.add(app.toMonitored()) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 2)
        }
        .listStyle(.inset)
    }
}

// MARK: - Settings tab

private struct PreferencesTab: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var accessibilityTrusted = Accessibility.isTrusted

    @AppStorage(SettingsKeys.showCount) private var showCount = true
    @AppStorage(SettingsKeys.hideWhenNoBadge) private var hideWhenNoBadge = false
    @AppStorage(SettingsKeys.dimWhenNoBadge) private var dimWhenNoBadge = false
    @AppStorage(SettingsKeys.hideWhenAppNotRunning) private var hideWhenAppNotRunning = false
    @AppStorage(SettingsKeys.floatingAlert) private var floatingAlert = true
    @AppStorage(SettingsKeys.floatingAlertDuration) private var floatingAlertDuration = 4.0

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(v)"
    }

    var body: some View {
        Form {
            Section("Menu bar") {
                Toggle(isOn: $showCount) {
                    Text("Show unread count")
                    Text("Off: show a small red dot instead of the number.")
                }
                Toggle(isOn: $hideWhenNoBadge) {
                    Text("Only show an app when it has a notification")
                    Text("Hides the icon completely until there's an unread badge.")
                }
                Toggle(isOn: $dimWhenNoBadge) {
                    Text("Dim the icon when there's no notification")
                    Text("Greys out the icon instead of hiding it. Ignored when the option above is on.")
                }
                .disabled(hideWhenNoBadge)
                Toggle(isOn: $hideWhenAppNotRunning) {
                    Text("Hide an app when it isn't running")
                    Text("Removes the icon while the app is closed.")
                }
            }

            Section("On-screen alert") {
                Toggle(isOn: $floatingAlert) {
                    Text("Show a floating alert on new messages")
                    Text("Appears briefly on top of everything — even full-screen apps.")
                }
                Picker("Stay on screen for", selection: $floatingAlertDuration) {
                    Text("2 seconds").tag(2.0)
                    Text("4 seconds").tag(4.0)
                    Text("6 seconds").tag(6.0)
                }
                .disabled(!floatingAlert)
            }

            Section("General") {
                Toggle("Launch BadgeBar at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        if !LaunchAtLogin.set(newValue) {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityTrusted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility access")
                        Text(accessibilityTrusted
                             ? "Granted — badges can be read from the Dock."
                             : "Required to read badges from the Dock.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Settings") { openAccessibilitySettings() }
                }
            }

            Section {
                LabeledContent("About") {
                    Text(version).foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Quit BadgeBar") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { accessibilityTrusted = Accessibility.isTrusted }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

/// Small cached helper so SwiftUI rows don't re-resolve app icons constantly.
enum AppIconLoader {
    static func icon(forBundleId bundleId: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
