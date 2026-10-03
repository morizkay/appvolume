import AppKit

struct AudioSession: Identifiable, Equatable {
    let bundleIdentifier: String
    let processID: Int32
    let name: String
    let icon: NSImage?
    let outputDeviceObjectID: UInt32?
    var outputDeviceID: String?
    var outputDeviceName: String?
    let isActive: Bool
    let hasBundleIdentifier: Bool

    var id: String { bundleIdentifier }

    static func == (lhs: AudioSession, rhs: AudioSession) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.processID == rhs.processID &&
        lhs.name == rhs.name &&
        lhs.outputDeviceObjectID == rhs.outputDeviceObjectID &&
        lhs.outputDeviceID == rhs.outputDeviceID &&
        lhs.outputDeviceName == rhs.outputDeviceName &&
        lhs.isActive == rhs.isActive &&
        lhs.hasBundleIdentifier == rhs.hasBundleIdentifier
    }
}

struct SystemAudioState: Equatable {
    var volume: Double
    var isMuted: Bool
    var outputDevice: AudioDevice?
    var canSetVolume: Bool
    var canMute: Bool
    var notice: String?

    static let unavailable = SystemAudioState(
        volume: 1,
        isMuted: false,
        outputDevice: nil,
        canSetVolume: false,
        canMute: false,
        notice: "No default output device is available."
    )
}

struct AudioSnapshot {
    let applications: [AudioSession]
    let devices: [AudioDevice]
    let system: SystemAudioState
    let notice: String?
}
