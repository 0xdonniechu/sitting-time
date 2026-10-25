import Foundation
import UserNotifications

/// Local-notification wrapper. Pure value type so the store stays testable:
/// production uses `.live`, tests inject a spy closure instead.
public struct ReminderCenter: Sendable {
    /// Asks for permission. Safe to call on every launch: the system prompts only once.
    public var requestAccess: @Sendable () async -> Bool
    /// Posts one notification (title, body, playSound).
    public var post: @Sendable (String, String, Bool) -> Void
    /// Current authorization status, for the Settings screen.
    public var isAuthorized: @Sendable () async -> Bool

    public init(
        requestAccess: @escaping @Sendable () async -> Bool,
        post: @escaping @Sendable (String, String, Bool) -> Void,
        isAuthorized: @escaping @Sendable () async -> Bool
    ) {
        self.requestAccess = requestAccess
        self.post = post
        self.isAuthorized = isAuthorized
    }

    public static let live = ReminderCenter(
        requestAccess: {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                fputs("SittingTime: notification permission granted=\(granted)\n", stderr)
                return granted
            } catch {
                fputs("SittingTime: notification permission request failed (\(error))\n", stderr)
                return false
            }
        },
        post: { title, body, sound in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if sound { content.sound = .default }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // deliver immediately
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    fputs("SittingTime: notification not delivered (\(error))\n", stderr)
                }
            }
        },
        isAuthorized: {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
        }
    )

    /// No-op implementation for Previews and tests.
    public static let silent = ReminderCenter(
        requestAccess: { false },
        post: { _, _, _ in },
        isAuthorized: { false }
    )
}
