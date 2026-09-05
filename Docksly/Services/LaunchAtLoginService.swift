import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` (macOS 13+). Register works after you install
/// the app in `/Applications`. A debug build from Xcode can fail to register.
enum LaunchAtLoginService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Docksly opens when you log in."
        case .notRegistered:
            return "Docksly does not open when you log in."
        case .notFound:
            return "macOS cannot find the login item. Put Docksly in the Applications folder, then try again."
        case .requiresApproval:
            return "macOS waits for your approval in System Settings → General → Login Items."
        @unknown default:
            return "Login status is not known."
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status == .enabled { return }
            try SMAppService.mainApp.register()
        } else {
            if SMAppService.mainApp.status == .notRegistered { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
