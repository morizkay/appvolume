import AppKit
import Foundation

final class MockAudioService: AudioService {
    let capabilities = AudioCapabilities(
        canControlApplicationVolume: true,
        canMuteApplications: true,
        canRouteApplications: true,
        canControlSystemVolume: true,
        explanation: "Mock audio service"
    )

    private(set) var sessions: [AudioSession]
    private(set) var devices: [AudioDevice]
    private(set) var systemVolume: Double
    private(set) var systemMuted: Bool
    private(set) var applicationVolumes: [String: Double]
    private(set) var applicationMutes: [String: Bool]
    private(set) var defaultOutputDeviceID: String

    init(
        sessions: [AudioSession] = MockAudioService.defaultSessions,
        devices: [AudioDevice] = MockAudioService.defaultDevices,
        systemVolume: Double = 0.72,
        systemMuted: Bool = false
    ) {
        self.sessions = sessions
        self.devices = devices
        self.systemVolume = systemVolume
        self.systemMuted = systemMuted
        self.applicationVolumes = sessions.reduce(into: [:]) { $0[$1.bundleIdentifier] = 1 }
        self.applicationMutes = sessions.reduce(into: [:]) { $0[$1.bundleIdentifier] = false }
        self.defaultOutputDeviceID = devices.first(where: { $0.isDefaultOutput })?.uid ?? devices.first?.uid ?? ""
    }

    func snapshot() throws -> AudioSnapshot {
        let systemDevice = devices.first(where: { $0.uid == defaultOutputDeviceID })
        let system = SystemAudioState(
            volume: systemVolume,
            isMuted: systemMuted,
            outputDevice: systemDevice,
            canSetVolume: true,
            canMute: true,
            notice: nil
        )
        return AudioSnapshot(applications: sessions, devices: devices, system: system, notice: nil)
    }

    func setApplicationVolume(_ volume: Double, for bundleIdentifier: String) throws {
        guard sessions.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AudioServiceError.processNotFound(bundleIdentifier)
        }
        applicationVolumes[bundleIdentifier] = min(max(volume, 0), 1)
    }

    func setApplicationMuted(_ muted: Bool, for bundleIdentifier: String) throws {
        guard sessions.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AudioServiceError.processNotFound(bundleIdentifier)
        }
        applicationMutes[bundleIdentifier] = muted
    }

    func setApplicationOutputDevice(_ deviceID: String, for bundleIdentifier: String) throws {
        guard devices.contains(where: { $0.uid == deviceID }) else {
            throw AudioServiceError.deviceNotFound(deviceID)
        }
        guard sessions.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AudioServiceError.processNotFound(bundleIdentifier)
        }
        if let index = sessions.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            sessions[index].outputDeviceID = deviceID
            sessions[index].outputDeviceName = devices.first(where: { $0.uid == deviceID })?.name
        }
    }

    func setSystemVolume(_ volume: Double) throws {
        systemVolume = min(max(volume, 0), 1)
    }

    func setSystemMuted(_ muted: Bool) throws {
        systemMuted = muted
    }

    func openSoundSettings() {}

    func addSession(_ session: AudioSession) {
        sessions.append(session)
        applicationVolumes[session.bundleIdentifier] = 1
        applicationMutes[session.bundleIdentifier] = false
    }

    func removeSession(bundleIdentifier: String) {
        sessions.removeAll { $0.bundleIdentifier == bundleIdentifier }
    }

    static let defaultDevices: [AudioDevice] = [
        AudioDevice(objectID: 1, uid: "mock.speakers", name: "MacBook Speakers", isVirtual: false, isDefaultOutput: true),
        AudioDevice(objectID: 2, uid: "mock.airpods", name: "AirPods", isVirtual: false, isDefaultOutput: false),
        AudioDevice(objectID: 3, uid: "mock.virtual", name: "Virtual Audio Device", isVirtual: true, isDefaultOutput: false)
    ]

    static let defaultSessions: [AudioSession] = [
        AudioSession(
            bundleIdentifier: "com.spotify.client",
            processID: 101,
            name: "Spotify",
            icon: NSImage(systemSymbolName: "music.note", accessibilityDescription: "Spotify"),
            outputDeviceObjectID: 1,
            outputDeviceID: "mock.speakers",
            outputDeviceName: "MacBook Speakers",
            isActive: true,
            hasBundleIdentifier: true
        ),
        AudioSession(
            bundleIdentifier: "com.google.Chrome",
            processID: 102,
            name: "Google Chrome",
            icon: NSImage(systemSymbolName: "globe", accessibilityDescription: "Google Chrome"),
            outputDeviceObjectID: 1,
            outputDeviceID: "mock.speakers",
            outputDeviceName: "MacBook Speakers",
            isActive: true,
            hasBundleIdentifier: true
        )
    ]
}
