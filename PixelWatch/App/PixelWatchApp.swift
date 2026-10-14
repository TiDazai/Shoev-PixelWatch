import SwiftUI
import AppKit

@main struct PixelWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { LocalizedRoot(store: delegate.store, content: SettingsView(store: delegate.store)) } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = WatchStore()
    private var statusItem: NSStatusItem?
    private var dashboard: NSWindow?
    private var settings: NSWindow?
    private var onboarding: NSWindow?
    private var editor: NSWindow?
    private var replacement: WatchConfiguration?
    private var chooser: NSWindow?
    private lazy var selection = SourceSelectionController(capture: store.capture)
    private var menuTimer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["PIXELWATCH_TESTING"] == "1" { return }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        store.languageDidChange = { [weak self] language in self?.relocalizeWindows(language); self?.updateMenu() }
        updateMenu()
        selection.onCancel = { [weak self] in Task { @MainActor in
            await self?.store.monitoring.setSuspended("selection", false); self?.openDashboard()
        } }
        selection.onError = { [weak self] message in Task { @MainActor in
            await self?.store.monitoring.setSuspended("selection", false); self?.store.errorMessage = message; self?.openDashboard()
        } }
        store.notifications.onOpenWatch = { [weak self] id in self?.store.selectedID = id; self?.openDashboard() }
        store.monitoring.start()
        menuTimer = Timer.scheduledTimer(withTimeInterval:2,repeats:true) { [weak self] _ in Task { @MainActor in self?.updateMenu() } }
        if !store.data.settings.onboardingComplete { openOnboarding() }
        else if !store.data.settings.startMinimized { openDashboard() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender:NSApplication) -> NSApplication.TerminateReply {
        menuTimer?.invalidate(); store.persist()
        Task { await store.monitoring.shutdown(); NSApp.reply(toApplicationShouldTerminate:true) }
        return .terminateLater
    }
    private func updateMenu() {
        guard let statusItem else { return }
        statusItem.button?.image = NSImage(systemSymbolName:store.activeCount > 0 ? "viewfinder.circle.fill" : "viewfinder",accessibilityDescription:"PixelWatch")
        statusItem.button?.title = store.data.settings.menuShowsCount && store.activeCount > 0 ? " \(store.activeCount)" : ""
        let menu = NSMenu()
        add(store.text("New Watch…"),#selector(newWatch),to:menu,key:"n")
        let active = NSMenuItem(title:store.format("Active Watches (%ld)", store.activeCount),action:nil,keyEquivalent:"")
        let submenu = NSMenu()
        for w in store.data.watches {
            let item = NSMenuItem(title:"\(w.name) · \(store.text(w.status.rawValue))",action:#selector(openWatch(_:)),keyEquivalent:"")
            item.target = self; item.representedObject = w.id; submenu.addItem(item)
        }
        if submenu.items.isEmpty { submenu.addItem(NSMenuItem(title:store.text("No watches yet"),action:nil,keyEquivalent:"")) }
        active.submenu = submenu; menu.addItem(active); menu.addItem(.separator())
        add(store.text("Pause All"),#selector(pauseAll),to:menu); add(store.text("Resume All"),#selector(resumeAll),to:menu)
        menu.addItem(.separator()); add(store.text("Open Dashboard"),#selector(openDashboard),to:menu,key:"d"); add(store.text("Settings…"),#selector(openSettings),to:menu,key:",")
        menu.addItem(.separator()); add(store.text("Quit PixelWatch"),#selector(quit),to:menu,key:"q"); statusItem.menu = menu
    }
    private func add(_ title:String,_ action:Selector,to menu:NSMenu,key:String = "") {
        let item = NSMenuItem(title:title,action:action,keyEquivalent:key); item.target = self; menu.addItem(item)
    }
    @objc private func pauseAll() { Task { await store.pauseAll(); updateMenu() } }
    @objc private func resumeAll() { Task { await store.resumeAll(); updateMenu() } }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func openWatch(_ sender:NSMenuItem) { store.selectedID = sender.representedObject as? UUID; openDashboard() }
    @objc func openDashboard() {
        if dashboard == nil {
            dashboard = makeWindow(title:"SHOEV PixelWatch",size:NSSize(width:1060,height:740),view:DashboardView(store:store,newWatch:{ [weak self] in self?.newWatch() },reselect:{ [weak self] watch in self?.replacement = watch; self?.chooseSource() }))
            dashboard?.setFrameAutosaveName("PixelWatchDashboard")
        }
        show(dashboard)
    }
    @objc private func openSettings() {
        if settings == nil { settings = makeWindow(title:"PixelWatch Settings",size:NSSize(width:620,height:560),view:SettingsView(store:store)) }
        show(settings)
    }
    @objc private func newWatch() { replacement = nil; chooseSource() }
    private func chooseSource() {
        chooser = makeWindow(title:"Choose a source",size:NSSize(width:460,height:310),view:SourceChoiceView(selection:selection,choose:{ [weak self] kind in self?.beginSelection(kind) }))
        show(chooser)
    }
    private func beginSelection(_ kind:CaptureSource.Kind) {
        if #available(macOS 15.2, *) { chooser?.orderOut(nil) }; dashboard?.orderOut(nil); settings?.orderOut(nil)
        Task { @MainActor in
        await store.monitoring.setSuspended("selection", true)
        selection.language = store.data.settings.language
        selection.choose(kind) { [weak self] source,filter,preview in
            guard let self else { return }
            chooser?.orderOut(nil)
            var watch = replacement ?? WatchConfiguration(name:store.text(source.kind == .display ? "Screen Watch" : "Window Watch"),source:source,rule:store.data.settings.defaults)
            let existing = replacement != nil
            watch.source = source
            if existing { watch.status = .active }
            editor = makeWindow(title:"New Watch",size:NSSize(width:540,height:700),view:WatchEditorView(store:store,watch:watch,filter:filter,preview:preview,existing:existing,onClose:{ [weak self] in self?.editor?.close(); self?.openDashboard() }))
            show(editor)
            Task { await self.store.monitoring.setSuspended("selection", false) }
        }
        }
    }
    private func openOnboarding() {
        onboarding = makeWindow(title:"Welcome to PixelWatch",size:NSSize(width:560,height:450),view:OnboardingView(store:store,finish:{ [weak self] create in
            self?.onboarding?.close(); if create { self?.newWatch() } else { self?.openDashboard() }
        })); show(onboarding)
    }
    private func makeWindow<V:View>(title:String,size:NSSize,view:V) -> NSWindow {
        let window = NSWindow(contentRect:NSRect(origin:.zero,size:size),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.identifier = NSUserInterfaceItemIdentifier(title); window.title = store.text(title); window.isReleasedWhenClosed = false; window.contentView = NSHostingView(rootView:LocalizedRoot(store:store,content:view)); window.center()
        return window
    }
    private func relocalizeWindows(_ language: String) {
        for window in [dashboard, settings, onboarding, editor, chooser].compactMap({ $0 }) {
            if let key = window.identifier?.rawValue { window.title = L10n.text(key, language: language) }
        }
    }
    private func show(_ window:NSWindow?) { NSApp.activate(ignoringOtherApps:true); window?.makeKeyAndOrderFront(nil) }
}
private struct SourceChoiceView:View {
    @ObservedObject var selection:SourceSelectionController
    var choose:(CaptureSource.Kind)->Void
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            Text("What would you like to watch?").font(.title2.bold())
            Button { choose(.display) } label: {
                HStack { Image(systemName:"display").font(.title2).foregroundStyle(Design.accent); VStack(alignment:.leading) { Text("Screen Region").font(.headline); Text("A fixed area of visible pixels on a display.").font(.caption).foregroundStyle(.secondary) }; Spacer() }.padding(12).foregroundStyle(.primary)
            }
            Button { choose(.window) } label: {
                HStack { Image(systemName:"macwindow").font(.title2).foregroundStyle(Design.accent); VStack(alignment:.leading) { Text("Application Window").font(.headline); Text("Follow a window as it moves.").font(.caption).foregroundStyle(.secondary) }; Spacer() }.padding(12).foregroundStyle(.primary)
            }
            Text("macOS controls access. You choose exactly what to share.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).buttonStyle(.bordered).tint(Design.accent)
        .sheet(isPresented:$selection.showLegacy) {
            VStack(alignment:.leading) { Text("Choose a source").font(.headline); List(selection.legacySources,id:\.id) { source in Button(source.name) {selection.chooseLegacy(source)} }; Button("Cancel") { selection.cancel() } }.padding().frame(width:520,height:400)
        }
    }
}
