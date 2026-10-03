import Foundation

@MainActor
final class AudioApplicationViewModel: ObservableObject, Identifiable {
    @Published private(set) var application: AudioApplication
    @Published var errorMessage: String?
    private let identifier: String

    private let audioService: AudioService
    private let persistence: PersistenceServicing
    private var devices: [AudioDevice]

    init(
        application: AudioApplication,
        devices: [AudioDevice],
        audioService: AudioService,
        persistence: PersistenceServicing
    ) {
        self.application = application
        self.identifier = application.id
        self.devices = devices
        self.audioService = audioService
        self.persistence = persistence
    }

    nonisolated var id: String { identifier }
    var canSetVolume: Bool { application.isActive && application.capabilities.canSetVolume }
    var canMute: Bool { application.isActive && application.capabilities.canMute }
    var canRouteOutput: Bool { application.isActive && application.capabilities.canRouteOutput }
    var volumePercent: Int { Int((application.volume * 100).rounded()) }

    func updateDevices(_ devices: [AudioDevice]) {
        self.devices = devices
        if let outputDevice = application.outputDevice,
           let updatedDevice = devices.first(where: { $0.uid == outputDevice.uid }) {
            application.outputDevice = updatedDevice
        }
    }

    func setVolume(_ value: Double) {
        guard canSetVolume else { return }
        let newValue = min(max(value, 0), 1)
        do {
            try audioService.setApplicationVolume(newValue, for: application.bundleIdentifier)
            application.volume = newValue
            persistence.saveVolume(newValue, for: application.bundleIdentifier)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMute() {
        guard canMute else { return }
        let newValue = !application.isMuted
        do {
            try audioService.setApplicationMuted(newValue, for: application.bundleIdentifier)
            application.isMuted = newValue
            persistence.saveMute(newValue, for: application.bundleIdentifier)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        guard application.isActive,
              application.capabilities.canSetVolume || application.capabilities.canMute else { return }

        let oldVolume = application.volume
        let oldMute = application.isMuted
        do {
            if application.capabilities.canSetVolume {
                try audioService.setApplicationVolume(1, for: application.bundleIdentifier)
                application.volume = 1
                persistence.saveVolume(1, for: application.bundleIdentifier)
            }
            if application.capabilities.canMute {
                try audioService.setApplicationMuted(false, for: application.bundleIdentifier)
                application.isMuted = false
                persistence.saveMute(false, for: application.bundleIdentifier)
            }
            errorMessage = nil
        } catch {
            application.volume = oldVolume
            application.isMuted = oldMute
            errorMessage = error.localizedDescription
        }
    }

    func setOutputDevice(_ deviceID: String) {
        guard canRouteOutput,
              let device = devices.first(where: { $0.uid == deviceID }) else { return }

        do {
            try audioService.setApplicationOutputDevice(deviceID, for: application.bundleIdentifier)
            application.outputDevice = device
            persistence.saveOutputDevice(deviceID, for: application.bundleIdentifier)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
