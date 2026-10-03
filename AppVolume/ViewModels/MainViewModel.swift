import Foundation
import OSLog

@MainActor
final class MainViewModel: ObservableObject {
    @Published private(set) var applications: [AudioApplicationViewModel] = []
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var systemState = SystemAudioState.unavailable
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var noticeMessage: String?
    @Published private(set) var lastRefreshDate: Date?
    @Published var actionErrorMessage: String?

    let audioCapabilities: AudioCapabilities

    private let audioService: AudioService
    private let persistence: PersistenceServicing
    private let logger = Logger(subsystem: "com.morizkay.AppVolume", category: "MainViewModel")
    private var settings: AppSettings
    private var knownSessions: [String: AudioSession] = [:]
    private var refreshTimer: Timer?

    init(audioService: AudioService, persistence: PersistenceServicing) {
        self.audioService = audioService
        self.persistence = persistence
        self.settings = persistence.loadSettings()
        self.audioCapabilities = audioService.capabilities
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var refreshInterval: TimeInterval { settings.refreshInterval }
    var showsInactiveApplications: Bool { settings.showInactiveAudioApplications }

    func start() {
        guard refreshTimer == nil else { return }
        refresh()
        scheduleRefreshTimer()
    }

    func refresh() {
        isLoading = applications.isEmpty
        do {
            let snapshot = try audioService.snapshot()
            devices = snapshot.devices
            systemState = snapshot.system
            noticeMessage = snapshot.notice
            updateApplications(from: snapshot.applications)
            errorMessage = nil
            lastRefreshDate = Date()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            logger.error("Audio refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func apply(settings newSettings: AppSettings) {
        var normalized = newSettings
        normalized.normalize()
        let intervalChanged = settings.refreshInterval != normalized.refreshInterval
        settings = normalized

        if intervalChanged, refreshTimer != nil {
            scheduleRefreshTimer()
        }
        refresh()
    }

    func setSystemVolume(_ value: Double) {
        guard systemState.canSetVolume else { return }
        do {
            try audioService.setSystemVolume(value)
            systemState.volume = min(max(value, 0), 1)
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func toggleSystemMute() {
        guard systemState.canMute else { return }
        do {
            try audioService.setSystemMuted(!systemState.isMuted)
            systemState.isMuted.toggle()
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func openSoundSettings() {
        audioService.openSoundSettings()
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }

    private func updateApplications(from sessions: [AudioSession]) {
        let activeSessions = AudioApplicationScanner.deduplicate(sessions)
        let activeIdentifiers = Set(activeSessions.map(\.bundleIdentifier))
        for session in activeSessions {
            knownSessions[session.bundleIdentifier] = session
        }

        let sessionsToDisplay: [AudioSession]
        if settings.showInactiveAudioApplications {
            sessionsToDisplay = knownSessions.values.map { session in
                if activeIdentifiers.contains(session.bundleIdentifier) {
                    return session
                }
                return session.withActive(false)
            }
        } else {
            knownSessions = Dictionary(uniqueKeysWithValues: activeSessions.map { ($0.bundleIdentifier, $0) })
            sessionsToDisplay = activeSessions
        }

        applications = sessionsToDisplay
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { makeApplicationViewModel(from: $0) }
    }

    private func makeApplicationViewModel(from session: AudioSession) -> AudioApplicationViewModel {
        let outputDevice = session.outputDeviceID.flatMap { deviceID in
            devices.first(where: { $0.uid == deviceID })
        } ?? session.outputDeviceObjectID.flatMap { objectID in
            devices.first(where: { $0.objectID == objectID })
        }

        let volume = settings.restorePreviousAppVolumes
            ? min(max(persistence.savedVolume(for: session.bundleIdentifier) ?? 1, 0), 1)
            : 1
        let muted = settings.restorePreviousAppVolumes
            ? persistence.savedMute(for: session.bundleIdentifier) ?? false
            : false
        let application = AudioApplication(
            bundleIdentifier: session.bundleIdentifier,
            processID: session.processID,
            name: session.name,
            icon: session.icon,
            volume: volume,
            isMuted: muted,
            outputDevice: outputDevice,
            isActive: session.isActive,
            capabilities: AudioApplicationCapabilities(
                canSetVolume: audioCapabilities.canControlApplicationVolume,
                canMute: audioCapabilities.canMuteApplications,
                canRouteOutput: audioCapabilities.canRouteApplications,
                explanation: audioCapabilities.explanation
            )
        )
        return AudioApplicationViewModel(
            application: application,
            devices: devices,
            audioService: audioService,
            persistence: persistence
        )
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        let interval = min(max(settings.refreshInterval, 0.25), 1.0)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
}

private extension AudioSession {
    func withActive(_ active: Bool) -> AudioSession {
        AudioSession(
            bundleIdentifier: bundleIdentifier,
            processID: processID,
            name: name,
            icon: icon,
            outputDeviceObjectID: outputDeviceObjectID,
            outputDeviceID: outputDeviceID,
            outputDeviceName: outputDeviceName,
            isActive: active,
            hasBundleIdentifier: hasBundleIdentifier
        )
    }
}
