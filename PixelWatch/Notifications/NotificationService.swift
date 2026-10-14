import AppKit
import UserNotifications
@MainActor final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var onOpenWatch: ((UUID) -> Void)?
    @Published var authorization: UNAuthorizationStatus = .notDetermined
    override init() { super.init(); UNUserNotificationCenter.current().delegate = self }
    func refresh() async { authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }
    func request() async throws {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refresh()
    }
    func send(event: WatchEvent, name: String, settings: AppSettings) async throws {
        guard settings.notifications else { return }
        await refresh()
        guard authorization == .authorized || authorization == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.format("PixelWatch — %@", name, language: settings.language)
        content.body = EventPresentation.reason(event, language: settings.language)
        content.userInfo = ["watchID": event.watchID.uuidString]
        if settings.sound { content.sound = .default }
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil))
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let raw = response.notification.request.content.userInfo["watchID"] as? String, let id = UUID(uuidString: raw) {
            await MainActor.run { self.onOpenWatch?(id) }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
}
