import AppKit

struct AudioApplicationCapabilities: Equatable {
    let canSetVolume: Bool
    let canMute: Bool
    let canRouteOutput: Bool
    let explanation: String
}

struct AudioApplication: Identifiable, Equatable {
    let bundleIdentifier: String
    let processID: Int32
    let name: String
    let icon: NSImage?
    var volume: Double
    var isMuted: Bool
    var outputDevice: AudioDevice?
    var isActive: Bool
    let capabilities: AudioApplicationCapabilities

    var id: String { bundleIdentifier }

    static func == (lhs: AudioApplication, rhs: AudioApplication) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.processID == rhs.processID &&
        lhs.name == rhs.name &&
        lhs.volume == rhs.volume &&
        lhs.isMuted == rhs.isMuted &&
        lhs.outputDevice == rhs.outputDevice &&
        lhs.isActive == rhs.isActive &&
        lhs.capabilities == rhs.capabilities
    }
}
