import SwiftUI
import ServiceManagement
struct SettingsView: View {
    @ObservedObject var store: WatchStore
    @State private var tab = 0
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var deleting = false
    private let sections = [("General","gearshape"),("Monitoring","viewfinder"),("Notifications","bell"),("Privacy","lock.shield"),("About","info.circle")]
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(sections.indices, id: \.self) { index in
                    Button { tab = index } label: {
                        VStack(spacing: 6) {
                            Image(systemName: sections[index].1).font(.system(size: 20, weight: .regular))
                            Text(LocalizedStringKey(sections[index].0)).font(.caption)
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(tab == index ? Design.accent : Design.silver)
                            .background(tab == index ? Design.gold.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(tab == index ? Design.gold.opacity(0.35) : .clear))
                    }.buttonStyle(.plain)
                }
            }
            Divider().overlay(Design.edge)
            Group {
                switch tab {
                case 0: general
                case 1: Form { RuleFields(rule: $store.data.settings.defaults) }
                case 2: notifications
                case 3: privacy
                default: about
                }
            }.frame(maxWidth: .infinity,maxHeight: .infinity)
        }.formStyle(.grouped).padding(20).frame(width:620,height:560)
            .background(Design.background).tint(Design.accent)
            .onChange(of: store.data.settings) { _,_ in store.persist() }
            .task { await store.refreshPermissions() }
            .alert("Delete all PixelWatch data?",isPresented:$deleting) {
                Button("Cancel",role:.cancel) {}
                Button("Delete All",role:.destructive) { Task { await store.deleteAllData() } }
            } message: { Text("Monitoring stops. All saved rules, settings and event history are permanently deleted.") }
            .alert("PixelWatch",isPresented:Binding(get:{store.errorMessage != nil},set:{if !$0 {store.errorMessage = nil}})) {
                Button("OK") {store.errorMessage = nil}
            } message: {Text(LocalizedStringKey(store.errorMessage ?? ""))}
    }
    private var general: some View {
        Form {
            Toggle("Launch at Login", isOn: $loginEnabled).onChange(of: loginEnabled) { _, value in
                do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                catch { loginEnabled = SMAppService.mainApp.status == .enabled; store.errorMessage = error.localizedDescription }
            }
            Toggle("Start minimized", isOn: $store.data.settings.startMinimized)
            Toggle("Show active watch count in menu bar", isOn: $store.data.settings.menuShowsCount)
            Picker("Language", selection: $store.data.settings.language) {
                Text(verbatim: "Русский").tag("ru")
                Text(verbatim: "English").tag("en")
            }
            Text("Language changes apply immediately to all app windows and menu items.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var notifications: some View {
        Form {
            Toggle("Enable notifications",isOn:$store.data.settings.notifications)
            Toggle("Notification sound",isOn:$store.data.settings.sound)
            LabeledContent("System permission",value:store.text(store.notificationStatus))
            HStack {
                Button("Enable Notifications") { Task { await store.requestNotifications() } }
                Button("System Settings") { PermissionService.openNotificationSettings() }
            }
            Button("Test Notification") { Task { await store.testNotification() } }.disabled(!store.data.settings.notifications)
        }
    }
    private var privacy: some View {
        Form {
            LabeledContent("Screen Recording",value:store.text(store.screenAllowed ? "Allowed" : "Permission required for saved watches"))
            HStack {
                Button("Request Permission") { PermissionService.requestScreen(); Task { await store.refreshPermissions() } }
                Button("Open System Settings") { PermissionService.openScreenSettings() }
            }
            Text("After enabling Screen Recording, macOS may ask you to quit and reopen PixelWatch. System picker access may be limited to this session.").font(.caption).foregroundStyle(.secondary)
            Text("Screenshots and OCR are processed locally in memory. No audio, cloud services, telemetry or image files. Only rules, settings and event text are saved.").font(.callout)
            LabeledContent("Local data") {
                Button("Show in Finder") { NSWorkspace.shared.selectFile(nil,inFileViewerRootedAtPath:store.repository.directory.path) }
            }
            Text(store.repository.directory.path).font(.caption).textSelection(.enabled)
            Button("Clear Event History") { store.clearHistory() }
            Button("Delete All Local Data…",role:.destructive) { deleting = true }
        }
    }
    private var about: some View {
        VStack(spacing: 14) {
            Image(systemName:"viewfinder").font(.system(size:48,weight:.light)).foregroundStyle(Design.gold)
            Text("SHOEV PixelWatch").font(.title2.bold())
            Text("Watch anything. Miss nothing.").foregroundStyle(.secondary)
            Text("Version 0.1.0 · MIT License").font(.caption)
            Text("SHOEV SYSTEMS\nSHOEV PRODUCTS").multilineTextAlignment(.center).font(.caption).foregroundStyle(Design.silver)
            Text("Free. Local. No subscriptions.").font(.caption)
            Link("GitHub", destination: URL(string: "https://github.com/TiDazai/Shoev-PixelWatch")!).font(.caption).foregroundStyle(Design.accent)
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
}
