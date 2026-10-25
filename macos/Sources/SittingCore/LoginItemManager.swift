import Foundation
import ServiceManagement

/// Launch-at-login through SMAppService. Only works from a bundled `.app`;
/// a raw binary (or `swift run`) throws, and the Settings screen shows that error.
public enum LoginItemManager {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
