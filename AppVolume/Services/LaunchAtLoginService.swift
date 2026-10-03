import Foundation
import ServiceManagement

protocol LaunchAtLoginService: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@available(macOS 13.0, *)
final class SystemLaunchAtLoginService: LaunchAtLoginService {
    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}
