import Foundation

enum AudioFeature: String, Equatable {
    case applicationScanning
    case applicationVolume
    case applicationMute
    case applicationRouting
    case systemVolume

    var displayName: String {
        switch self {
        case .applicationScanning: return "application audio detection"
        case .applicationVolume: return "per-application volume"
        case .applicationMute: return "per-application mute"
        case .applicationRouting: return "per-application output routing"
        case .systemVolume: return "system volume"
        }
    }
}

struct AudioCapabilities: Equatable {
    let canControlApplicationVolume: Bool
    let canMuteApplications: Bool
    let canRouteApplications: Bool
    let canControlSystemVolume: Bool
    let explanation: String
}

enum AudioServiceError: LocalizedError, Equatable {
    case unsupported(AudioFeature, String)
    case propertyUnavailable(String)
    case noDefaultOutputDevice
    case deviceNotFound(String)
    case processNotFound(String)
    case permissionDenied(String)
    case osStatus(Int32, operation: String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case let .unsupported(feature, explanation):
            return "\(feature.displayName.capitalized) is unavailable: \(explanation)"
        case let .propertyUnavailable(property):
            return "Core Audio property is unavailable: \(property)."
        case .noDefaultOutputDevice:
            return "macOS has no default output device right now."
        case let .deviceNotFound(deviceID):
            return "The output device \"\(deviceID)\" is no longer available."
        case let .processNotFound(identifier):
            return "The audio process \"\(identifier)\" is no longer available."
        case let .permissionDenied(explanation):
            return "Permission denied: \(explanation)"
        case let .osStatus(status, operation):
            return "Core Audio failed while \(operation) (OSStatus \(status))."
        case let .unavailable(explanation):
            return explanation
        }
    }
}

protocol AudioService: AnyObject {
    var capabilities: AudioCapabilities { get }

    func snapshot() throws -> AudioSnapshot
    func setApplicationVolume(_ volume: Double, for bundleIdentifier: String) throws
    func setApplicationMuted(_ muted: Bool, for bundleIdentifier: String) throws
    func setApplicationOutputDevice(_ deviceID: String, for bundleIdentifier: String) throws
    func setSystemVolume(_ volume: Double) throws
    func setSystemMuted(_ muted: Bool) throws
    func openSoundSettings()
}
