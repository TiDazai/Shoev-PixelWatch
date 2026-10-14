import AppKit
import CoreGraphics
import UserNotifications
@MainActor enum PermissionService {
    static var screenAllowed: Bool { CGPreflightScreenCaptureAccess() }
    static func requestScreen() { _ = CGRequestScreenCaptureAccess() }
    static func openScreenSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    static func openNotificationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }
}
