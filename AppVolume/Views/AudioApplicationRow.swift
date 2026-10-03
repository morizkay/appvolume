import SwiftUI

struct AudioApplicationRow: View {
    @ObservedObject var viewModel: AudioApplicationViewModel
    let devices: [AudioDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                applicationIcon
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(viewModel.application.name)
                            .font(.headline)
                            .lineLimit(1)
                        Circle()
                            .fill(viewModel.application.isActive ? .green : .gray)
                            .frame(width: 7, height: 7)
                            .accessibilityLabel(viewModel.application.isActive ? "Active" : "Inactive")
                    }
                    Text(viewModel.application.bundleIdentifier)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if !viewModel.application.isActive {
                    Text("Inactive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1.fill")
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { viewModel.application.volume },
                        set: viewModel.setVolume
                    ),
                    in: 0...1
                )
                .disabled(!viewModel.canSetVolume)
                .accessibilityLabel("\(viewModel.application.name) volume")
                Text("\(viewModel.volumePercent)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Button(action: viewModel.toggleMute) {
                    Label(
                        viewModel.application.isMuted ? "Unmute" : "Mute",
                        systemImage: viewModel.application.isMuted ? "speaker.wave.2" : "speaker.slash"
                    )
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canMute)

                Button(action: viewModel.reset) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canSetVolume && !viewModel.canMute)

                Spacer()

                OutputDevicePicker(
                    devices: devices,
                    selectedDeviceID: viewModel.application.outputDevice?.uid ?? "",
                    isEnabled: viewModel.canRouteOutput,
                    onSelection: viewModel.setOutputDevice
                )
            }

            if !viewModel.application.capabilities.canSetVolume ||
                !viewModel.application.capabilities.canMute ||
                !viewModel.application.capabilities.canRouteOutput {
                Label("Per-app controls are unavailable through public Core Audio", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var applicationIcon: some View {
        if let icon = viewModel.application.icon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(4)
        }
    }
}
