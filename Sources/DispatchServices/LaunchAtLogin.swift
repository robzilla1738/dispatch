import Foundation
import ServiceManagement

public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "Enabled"
        case .notRegistered: return "Not registered"
        case .notFound: return "Not registered"
        case .requiresApproval: return "Waiting for approval in System Settings"
        @unknown default: return "Unknown"
        }
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            try setEnabledThrowing(enabled)
            return true
        } catch {
            return false
        }
    }

    public static func setEnabledThrowing(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
