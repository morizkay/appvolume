import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: MainViewModel
    let onOpenMainWindow: (() -> Void)?
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let noticeMessage = viewModel.noticeMessage {
                Label(noticeMessage, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionErrorMessage = viewModel.actionErrorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Label(actionErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    Spacer()
                    Button("Dismiss", action: viewModel.dismissActionError)
                        .buttonStyle(.borderless)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

            Text("Audio applications")
                .font(.headline)

            applicationContent
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)

            Divider()
            SystemVolumeView(
                state: viewModel.systemState,
                onVolumeChange: viewModel.setSystemVolume,
                onToggleMute: viewModel.toggleSystemMute,
                onOpenSettings: viewModel.openSoundSettings
            )

            Divider()
            footer
        }
        .padding(16)
        .frame(minWidth: 390, minHeight: 560)
        .onAppear(perform: viewModel.start)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AppVolume")
                    .font(.title2)
                    .fontWeight(.semibold)
                if let lastRefreshDate = viewModel.lastRefreshDate {
                    Text("Updated \(lastRefreshDate.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: viewModel.refresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh audio applications")
            .accessibilityLabel("Refresh audio applications")
        }
    }

    @ViewBuilder
    private var applicationContent: some View {
        if viewModel.isLoading {
            ProgressView("Scanning Core Audio…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.applications.isEmpty {
            EmptyStateView(onRefresh: viewModel.refresh)
        } else {
            ScrollView {
                AudioApplicationListView(
                    applications: viewModel.applications,
                    devices: viewModel.devices
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings", action: onOpenSettings)
                .buttonStyle(.borderless)
            if let onOpenMainWindow {
                Button("Open Main Window", action: onOpenMainWindow)
                    .buttonStyle(.borderless)
            }
            Spacer()
            Button("Quit", action: onQuit)
                .buttonStyle(.borderless)
        }
        .font(.caption)
    }

}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let service = MockAudioService()
        let persistence = PersistenceService(defaults: UserDefaults(suiteName: "AppVolumePreview") ?? .standard)
        MainView(
            viewModel: MainViewModel(audioService: service, persistence: persistence),
            onOpenMainWindow: {},
            onOpenSettings: {},
            onQuit: {}
        )
    }
}
#endif
