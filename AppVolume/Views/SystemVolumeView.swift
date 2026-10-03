import SwiftUI

struct SystemVolumeView: View {
    let state: SystemAudioState
    let onVolumeChange: (Double) -> Void
    let onToggleMute: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("System volume", systemImage: state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.headline)
                Spacer()
                Text("\(Int((state.volume * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1.fill")
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(get: { state.volume }, set: onVolumeChange),
                    in: 0...1
                )
                .disabled(!state.canSetVolume)
                .accessibilityLabel("System volume")
            }

            HStack {
                Label(
                    state.outputDevice?.name ?? "No output device",
                    systemImage: "hifispeaker.and.homepod"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Spacer()

                Button(action: onToggleMute) {
                    Label(state.isMuted ? "Unmute" : "Mute", systemImage: state.isMuted ? "speaker.wave.2" : "speaker.slash")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canMute)

                Button("Sound Settings", action: onOpenSettings)
                    .buttonStyle(.borderless)
            }

            if let notice = state.notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}
