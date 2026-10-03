import AppKit
import Foundation
import OSLog

protocol SystemVolumeService: AnyObject {
    func currentState(devices: [AudioDevice]) throws -> SystemAudioState
    func setVolume(_ volume: Double) throws
    func setMuted(_ muted: Bool) throws
    func openSoundSettings()
}

final class CoreAudioSystemVolumeService: SystemVolumeService {
    private let logger = Logger(subsystem: "com.morizkay.AppVolume", category: "SystemVolume")

    func currentState(devices: [AudioDevice]) throws -> SystemAudioState {
        guard let defaultObjectID = try? CoreAudioHAL.defaultOutputDeviceObjectID(),
              let outputDevice = devices.first(where: { $0.objectID == defaultObjectID }) else {
            return .unavailable
        }

        let volume = try? CoreAudioHAL.systemVolume(for: outputDevice.objectID)
        let muted = try? CoreAudioHAL.systemMuted(for: outputDevice.objectID)
        let canSetVolume = volume != nil && CoreAudioHAL.isSystemVolumeSettable(for: outputDevice.objectID)
        let canMute = muted != nil && CoreAudioHAL.isSystemMuteSettable(for: outputDevice.objectID)

        var notice: String?
        if !canSetVolume || !canMute {
            notice = "The current output device does not expose every writable system control through Core Audio."
        }

        return SystemAudioState(
            volume: min(max(Double(volume ?? 1), 0), 1),
            isMuted: muted ?? false,
            outputDevice: outputDevice,
            canSetVolume: canSetVolume,
            canMute: canMute,
            notice: notice
        )
    }

    func setVolume(_ volume: Double) throws {
        let deviceID = try CoreAudioHAL.defaultOutputDeviceObjectID()
        try CoreAudioHAL.setSystemVolume(min(max(volume, 0), 1), for: deviceID)
        logger.debug("Set system output volume")
    }

    func setMuted(_ muted: Bool) throws {
        let deviceID = try CoreAudioHAL.defaultOutputDeviceObjectID()
        try CoreAudioHAL.setSystemMuted(muted, for: deviceID)
        logger.debug("Set system output mute to \(muted, privacy: .public)")
    }

    func openSoundSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") else {
            logger.error("Unable to create Sound Settings URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
