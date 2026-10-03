import SwiftUI

struct DiagnosticsView: View {
    let permissionStatuses: [PermissionStatus]
    let capabilities: AudioCapabilities
    let onRefresh: () -> Void

    var body: some View {
        Form {
            Section("Permissions") {
                ForEach(permissionStatuses) { status in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Label(status.title, systemImage: iconName(for: status.state))
                            Spacer()
                            Text(status.state.title)
                                .foregroundStyle(status.state == .denied ? .red : .secondary)
                        }
                        Text(status.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }

            Section("Audio capabilities") {
                capabilityRow("Detect active application audio", available: true)
                capabilityRow("Per-application volume", available: capabilities.canControlApplicationVolume)
                capabilityRow("Per-application mute", available: capabilities.canMuteApplications)
                capabilityRow("Per-application output routing", available: capabilities.canRouteApplications)
                capabilityRow("System volume", available: capabilities.canControlSystemVolume)
                Text(capabilities.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Refresh diagnostics", action: onRefresh)
        }
        .formStyle(.grouped)
        .padding()
    }

    private func capabilityRow(_ title: String, available: Bool) -> some View {
        Label(title, systemImage: available ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(available ? .primary : .secondary)
    }

    private func iconName(for state: PermissionState) -> String {
        switch state {
        case .available: return "checkmark.shield.fill"
        case .denied, .restricted: return "exclamationmark.triangle.fill"
        case .notDetermined: return "questionmark.circle"
        case .notRequired: return "minus.circle"
        }
    }
}
