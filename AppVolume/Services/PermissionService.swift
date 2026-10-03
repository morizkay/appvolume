import AVFoundation
import ApplicationServices
import Foundation

enum PermissionState: Equatable {
    case available
    case denied
    case notDetermined
    case notRequired
    case restricted

    var title: String {
        switch self {
        case .available: return "Available"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        case .notRequired: return "Not required"
        case .restricted: return "Restricted"
        }
    }
}

struct PermissionStatus: Identifiable, Equatable {
    let id: String
    let title: String
    let state: PermissionState
    let detail: String
    let isRequiredByMVP: Bool
}

protocol PermissionServicing: AnyObject {
    func statuses() -> [PermissionStatus]
}

final class PermissionService: PermissionServicing {
    func statuses() -> [PermissionStatus] {
        let microphoneState: PermissionState
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneState = .available
        case .denied:
            microphoneState = .denied
        case .restricted:
            microphoneState = .restricted
        case .notDetermined:
            microphoneState = .notDetermined
        @unknown default:
            microphoneState = .notDetermined
        }

        let accessibilityState: PermissionState = AXIsProcessTrusted() ? .available : .notRequired

        return [
            PermissionStatus(
                id: "microphone",
                title: "Microphone",
                state: microphoneState,
                detail: "The MVP only reads public Core Audio process metadata and does not request microphone access.",
                isRequiredByMVP: false
            ),
            PermissionStatus(
                id: "accessibility",
                title: "Accessibility",
                state: accessibilityState,
                detail: "Accessibility permission is not used. AppVolume does not send keystrokes or control other apps.",
                isRequiredByMVP: false
            ),
            PermissionStatus(
                id: "system-extension",
                title: "System extension / audio driver",
                state: .notRequired,
                detail: "No virtual audio driver or system extension is installed by this MVP.",
                isRequiredByMVP: false
            ),
            PermissionStatus(
                id: "system-audio-capture",
                title: "System audio capture",
                state: .notRequired,
                detail: "Process taps are not enabled. A future interception implementation would need its own consent flow.",
                isRequiredByMVP: false
            )
        ]
    }
}
