import SwiftUI
import ScreenCaptureKit
import UserNotifications
@MainActor final class WatchStore: ObservableObject {
    @Published var data = StoredData() {
        didSet { if oldValue.settings.language != data.settings.language { languageDidChange?(data.settings.language) } }
    }
    var languageDidChange: ((String) -> Void)?
    func text(_ key: String) -> String { L10n.text(key, language: data.settings.language) }
    func format(_ key: String, _ arguments: CVarArg...) -> String { L10n.format(key, arguments: arguments, language: data.settings.language) }
    @Published var previews: [UUID: CGImage] = [:]
    @Published var diagnostics: [UUID: Diagnostics] = [:]
    @Published var sourceMessages: [UUID: String] = [:]
    @Published var selectedID: UUID?
    @Published var errorMessage: String?
    @Published var screenAllowed = PermissionService.screenAllowed
    @Published var notificationStatus = "Not requested"
    let repository = WatchRepository()
    let capture = CaptureService()
    let notifications = NotificationService()
    lazy var monitoring = MonitoringCoordinator(store: self)
    var activeCount: Int { data.watches.filter { [.active, .waitingForSource, .permissionRequired].contains($0.status) }.count }
    init() {
        do { data = try repository.load() } catch { errorMessage = format("Local data could not be loaded. The original file was preserved: %@", error.localizedDescription) }
        data.watches = data.watches.map { var w = $0; w.rule = w.rule.validated(); return w }
    }
    func persist() {
        do { try repository.save(data) } catch { errorMessage = format("Could not save local data: %@", error.localizedDescription) }
    }
    func add(_ watch: WatchConfiguration, filter: SCContentFilter?, preview: CGImage?) {
        data.watches.append(watch); capture.pickerFilters[watch.id] = filter; previews[watch.id] = preview
        selectedID = watch.id; persist()
    }
    func update(_ watch: WatchConfiguration) async {
        if let i = data.watches.firstIndex(where: { $0.id == watch.id }) { data.watches[i].status = data.watches[i].status.transitioning(.pause) }
        await monitoring.reset(watch.id)
        if let i = data.watches.firstIndex(where: { $0.id == watch.id }) { data.watches[i] = watch; persist() }
    }
    func pause(_ id: UUID) async {
        guard let i = data.watches.firstIndex(where: { $0.id == id }) else { return }
        data.watches[i].status = data.watches[i].status.transitioning(.pause); persist(); await monitoring.reset(id)
    }
    func resume(_ id: UUID) async {
        capture.deniedSourceIDs.remove(id)
        await monitoring.reset(id)
        guard let i = data.watches.firstIndex(where: { $0.id == id }) else { return }
        data.watches[i].status = data.watches[i].status.transitioning(.resume); persist()
    }
    func pauseAll() async { for id in data.watches.map(\.id) { await pause(id) } }
    func resumeAll() async { for id in data.watches.map(\.id) { await resume(id) } }
    func delete(_ id: UUID) async {
        data.watches.removeAll { $0.id == id }; data.events.removeAll { $0.watchID == id }
        previews[id] = nil; diagnostics[id] = nil; sourceMessages[id] = nil; capture.pickerFilters[id] = nil; capture.deniedSourceIDs.remove(id)
        if selectedID == id { selectedID = nil }; persist(); await monitoring.reset(id)
    }
    func clearHistory() { data.events.removeAll(); persist() }
    func deleteAllData() async {
        await pauseAll(); await capture.stopAll()
        do {
            try repository.deleteAll()
            if let bundleID = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: bundleID) }
            data = StoredData(); previews.removeAll(); diagnostics.removeAll(); sourceMessages.removeAll(); capture.pickerFilters.removeAll(); capture.deniedSourceIDs.removeAll(); selectedID = nil
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        } catch { errorMessage = error.localizedDescription }
    }
    func requestNotifications() async {
        do { try await notifications.request(); await refreshPermissions() } catch { errorMessage = error.localizedDescription }
    }
    func refreshPermissions() async {
        screenAllowed = PermissionService.screenAllowed
        await notifications.refresh()
        switch notifications.authorization {
        case .authorized, .provisional: notificationStatus = "Allowed"
        case .denied: notificationStatus = "Denied — enable in System Settings"
        default: notificationStatus = "Not requested"
        }
    }
    func testNotification(_ id: UUID? = nil) async {
        await requestNotifications()
        guard notifications.authorization == .authorized || notifications.authorization == .provisional else {
            errorMessage = "Notifications are disabled. Enable PixelWatch in System Settings → Notifications."; return
        }
        let event = WatchEvent(watchID: id ?? UUID(), date: Date(), reason: "Your PixelWatch notifications are ready.")
        do { try await notifications.send(event: event, name: text("Test notification"), settings: data.settings) }
        catch { errorMessage = error.localizedDescription }
    }
}
