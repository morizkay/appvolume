import Foundation

struct AudioRoutingCapabilities: Equatable {
    let canRouteApplications: Bool
    let explanation: String
}

protocol AudioRoutingService: AnyObject {
    var capabilities: AudioRoutingCapabilities { get }
    func setOutputDevice(_ deviceID: String, for bundleIdentifier: String) throws
}

final class UnavailableAudioRoutingService: AudioRoutingService {
    let capabilities = AudioRoutingCapabilities(
        canRouteApplications: false,
        explanation: "Public Core Audio has no direct per-application output selector. Routing requires a separate audio interception/rendering pipeline, which AppVolume does not install or run."
    )

    func setOutputDevice(_ deviceID: String, for bundleIdentifier: String) throws {
        throw AudioServiceError.unsupported(.applicationRouting, capabilities.explanation)
    }
}
