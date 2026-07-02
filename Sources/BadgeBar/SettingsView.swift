import SwiftUI

/// The configuration window: an "Apps" tab to pick/reorder apps, and a
/// "Settings" tab for preferences.
struct SettingsView: View {
    @Bindable var store: AppStore

    var body: some View {
        TabView {
            AppsTab(store: store)
                .tabItem { Label(L.t("Apps"), systemImage: "square.grid.2x2") }

            PreferencesTab()
                .tabItem { Label(L.t("Settings"), systemImage: "gearshape") }
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
            searchField
            List {
                if !store.monitoredApps.isEmpty {
                    Section {
                        ForEach(store.monitoredApps) { app in
                            monitoredRow(app)
                        }
                        .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                    } header: {
                        Text(L.t("Monitoring"))
                    } footer: {
                        Text(L.t("Drag to reorder how icons appear in the menu bar."))
                            .font(.caption)
                    }
                }

                Section(L.t("All apps")) {
                    ForEach(filteredApps) { app in
                        appRow(app)
                    }
                }
            }
            .listStyle(.inset)
        }
        .onAppear {
            installed.load()
            if !Accessibility.isTrusted { Accessibility.prompt() }
        }
    }

    private func monitoredRow(_ app: MonitoredApp) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: AppIcons.icon(forBundleId: app.bundleId))
                .resizable()
                .frame(width: 22, height: 22)
            Text(app.name)
            Spacer()
            Button {
                store.remove(app.bundleId)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func appRow(_ app: AppInfo) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)
            Text(app.name)
            Spacer()
            if store.isMonitored(app.bundleId) {
                Button(L.t("Remove")) { store.remove(app.bundleId) }
                    .buttonStyle(.bordered)
            } else {
                Button(L.t("Add")) { store.add(app.toMonitored()) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 2)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L.t("Search apps…"), text: $search)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
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
    @AppStorage(SettingsKeys.showControlIcon) private var showControlIcon = false
    @AppStorage(SettingsKeys.floatingAlert) private var floatingAlert = true
    @AppStorage(SettingsKeys.floatingAlertDuration) private var floatingAlertDuration = 4.0
    @AppStorage(SettingsKeys.pollInterval) private var pollInterval = 1.0

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return L.t("Version %@", v)
    }

    var body: some View {
        Form {
            Section(L.t("Menu bar")) {
                Toggle(isOn: $showCount) {
                    Text(L.t("Show unread count"))
                    Text(L.t("Off: show a small red dot instead of the number."))
                }
                Toggle(isOn: $hideWhenNoBadge) {
                    Text(L.t("Only show an app when it has a notification"))
                    Text(L.t("Hides the icon completely until there's an unread badge."))
                }
                Toggle(isOn: $dimWhenNoBadge) {
                    Text(L.t("Dim the icon when there's no notification"))
                    Text(L.t("Greys out the icon instead of hiding it. Ignored when the option above is on."))
                }
                .disabled(hideWhenNoBadge)
                Toggle(isOn: $hideWhenAppNotRunning) {
                    Text(L.t("Hide an app when it isn't running"))
                    Text(L.t("Removes the icon while the app is closed."))
                }
                Toggle(isOn: $showControlIcon) {
                    Text(L.t("Always show a BadgeBar icon"))
                    Text(L.t("Keeps a small BadgeBar icon in the menu bar for quick access, even when nothing has a notification."))
                }
            }

            Section(L.t("On-screen alert")) {
                Toggle(isOn: $floatingAlert) {
                    Text(L.t("Show a floating alert on new messages"))
                    Text(L.t("Appears briefly on top of everything — even full-screen apps."))
                }
                Picker(L.t("Stay on screen for"), selection: $floatingAlertDuration) {
                    Text(L.t("2 seconds")).tag(2.0)
                    Text(L.t("4 seconds")).tag(4.0)
                    Text(L.t("6 seconds")).tag(6.0)
                }
                .disabled(!floatingAlert)
            }

            Section(L.t("General")) {
                Toggle(L.t("Launch BadgeBar at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        if !LaunchAtLogin.set(newValue) {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                Picker(L.t("Poll interval"), selection: $pollInterval) {
                    Text(L.t("1 second (default)")).tag(1.0)
                    Text(L.t("2 seconds")).tag(2.0)
                    Text(L.t("5 seconds")).tag(5.0)
                }
            }

            Section(L.t("Permissions")) {
                HStack {
                    Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityTrusted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("Accessibility access"))
                        Text(accessibilityTrusted
                             ? L.t("Granted — badges can be read from the Dock.")
                             : L.t("Required to read badges from the Dock."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L.t("Open Settings")) { openAccessibilitySettings() }
                }
            }

            Section {
                LabeledContent(L.t("About")) {
                    Text(version).foregroundStyle(.secondary)
                }
                HStack {
                    Button(L.t("Check for Updates…")) { checkForUpdates() }
                    Spacer()
                    Button(L.t("Quit BadgeBar")) { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            accessibilityTrusted = Accessibility.isTrusted
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func checkForUpdates() {
        Task {
            let result = await UpdateChecker.check()
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            if let result {
                if result.hasUpdate {
                    alert.messageText = L.t("Update available")
                    alert.informativeText = "BadgeBar \(result.latest)  (\(result.current))"
                    alert.addButton(withTitle: L.t("Download"))
                    alert.addButton(withTitle: L.t("Later"))
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(result.url)
                    }
                    return
                }
                alert.messageText = L.t("You're up to date")
                alert.informativeText = L.t("BadgeBar %@ is the latest version.", result.current)
            } else {
                alert.messageText = L.t("Couldn't check for updates")
                alert.informativeText = L.t("Please try again later.")
            }
            alert.addButton(withTitle: L.t("OK"))
            alert.runModal()
        }
    }
}
