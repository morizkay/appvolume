import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let capabilities: AudioCapabilities

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }

            DiagnosticsView(
                permissionStatuses: viewModel.permissionStatuses,
                capabilities: capabilities,
                onRefresh: viewModel.refreshPermissions
            )
            .tabItem { Label("Diagnostics", systemImage: "stethoscope") }
        }
        .frame(width: 520, height: 440)
        .alert("Settings error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var generalSettings: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { viewModel.settings.launchAtLogin },
                        set: viewModel.setLaunchAtLogin
                    )
                )
                Toggle(
                    "Start minimized / menu bar only",
                    isOn: Binding(
                        get: { viewModel.settings.startMinimized },
                        set: viewModel.setStartMinimized
                    )
                )
                Toggle(
                    "Open main window at startup",
                    isOn: Binding(
                        get: { viewModel.settings.openAtStartup },
                        set: viewModel.setOpenAtStartup
                    )
                )
                .disabled(viewModel.settings.startMinimized)
            }

            Section("Audio applications") {
                Toggle(
                    "Show inactive audio applications",
                    isOn: Binding(
                        get: { viewModel.settings.showInactiveAudioApplications },
                        set: viewModel.setShowInactive
                    )
                )
                Toggle(
                    "Restore previous per-app volume",
                    isOn: Binding(
                        get: { viewModel.settings.restorePreviousAppVolumes },
                        set: viewModel.setRestorePreviousVolumes
                    )
                )
                Picker(
                    "Refresh interval",
                    selection: Binding(
                        get: { viewModel.settings.refreshInterval },
                        set: viewModel.setRefreshInterval
                    )
                ) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.self) { interval in
                        Text(intervalText(interval)).tag(interval)
                    }
                }
            }

            Section("Saved values") {
                Text("Saved values are local UserDefaults entries keyed by bundle identifier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reset all saved app volumes", role: .destructive, action: viewModel.resetSavedAppVolumes)
            }

            Section("About") {
                HStack {
                    Text("AppVolume")
                    Spacer()
                    Text("MVP")
                        .foregroundStyle(.secondary)
                }
                Text("Native SwiftUI menu bar volume monitor for macOS. Per-app gain, mute, and routing remain explicitly disabled until a safe public implementation is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func intervalText(_ interval: TimeInterval) -> String {
        if interval < 1 {
            return "\(Int(interval * 1000)) ms"
        }
        return "1 second"
    }
}
