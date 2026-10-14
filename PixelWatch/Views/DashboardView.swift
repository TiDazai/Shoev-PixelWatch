import SwiftUI
struct DashboardView: View {
    @ObservedObject var store: WatchStore
    var newWatch: () -> Void
    var reselect: (WatchConfiguration) -> Void
    @State private var editing: WatchConfiguration?
    @State private var deleting: WatchConfiguration?
    var selected: WatchConfiguration? { store.data.watches.first { $0.id == store.selectedID } }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "viewfinder").font(.title2).foregroundStyle(Design.accent)
                VStack(alignment: .leading, spacing: 2) { Text("SHOEV PRODUCTS").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(Design.silver); Text("PixelWatch").font(.title2.weight(.semibold)); Text(store.format("Active watches: %ld", store.activeCount)).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button(action: newWatch) { Label("New Watch", systemImage: "plus") }.buttonStyle(.borderedProminent).foregroundStyle(Design.actionText).keyboardShortcut("n")
            }.padding(24)
            Rectangle().fill(Design.gold.opacity(0.5)).frame(height: 1)
            if store.data.watches.isEmpty {
                VStack(spacing: 18) {
                    Image(systemName: "viewfinder.circle").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(Design.accent)
                    Text("Keep an eye on what matters.").font(.title2.weight(.medium))
                    Text("Select an area. Set a rule. Get notified.\nPixelWatch keeps watching while you get back to work.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Create your first watch", action: newWatch).buttonStyle(.borderedProminent).foregroundStyle(Design.actionText)
                    Text("Local processing. No accounts. No cloud.").font(.caption).foregroundStyle(.tertiary)
                }.frame(maxWidth: .infinity,maxHeight: .infinity)
            } else {
                HSplitView {
                    List(selection: $store.selectedID) {
                        ForEach(store.data.watches) { watch in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    PreviewImage(image: store.previews[watch.id]).frame(width: 76,height: 52)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(watch.name).font(.headline).lineLimit(1)
                                        Text(LocalizedStringKey(watch.rule.mode.title)).font(.caption).foregroundStyle(.secondary)
                                        StatusBadge(status: watch.status)
                                    }
                                }
                                HStack {
                                    if let date = watch.lastAnalysis { Text(date, style: .relative).font(.caption2).foregroundStyle(.tertiary) }
                                    Spacer()
                                    Button { toggle(watch) } label: { Image(systemName: canResume(watch) ? "play.fill" : "pause.fill") }.help(Text(LocalizedStringKey(canResume(watch) ? "Resume" : "Pause")))
                                    Button { editing = watch } label: { Image(systemName: "slider.horizontal.3") }.help("Edit")
                                    Button { deleting = watch } label: { Image(systemName: "trash") }.help("Delete")
                                }.buttonStyle(.borderless)
                            }.padding(.vertical, 8).tag(watch.id)
                            .contextMenu { Button("Edit") { editing = watch }; Button("Delete", role: .destructive) { deleting = watch } }
                        }
                    }.listStyle(.sidebar).frame(minWidth: 270,idealWidth: 320,maxWidth: 400)
                    if let selected { WatchDetailsView(store: store, watch: selected, edit: { editing = selected }, reselect: { reselect(selected) }) }
                    else { Text("Select a watch to see its details.").foregroundStyle(.secondary).frame(maxWidth: .infinity,maxHeight: .infinity) }
                }
            }
            Divider()
            HStack {
                Image(systemName: "lock.shield"); Text("All analysis stays on your Mac.")
                Spacer(); Text("SHOEV PRODUCTS  /  0.1.5")
            }.font(.caption2).foregroundStyle(.tertiary).padding(.horizontal,24).padding(.vertical,12)
        }.background(Design.background).tint(Design.accent).frame(minWidth: 920,minHeight: 640)
            .sheet(item: $editing) { WatchEditorView(store: store, watch: $0, existing: true) }
            .alert("Delete this watch?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Cancel", role: .cancel) { deleting = nil }
                Button("Delete", role: .destructive) { if let w = deleting { Task { await store.delete(w.id) } }; deleting = nil }
            } message: { Text("The rule and its event history will be removed.") }
            .alert("PixelWatch", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") { store.errorMessage = nil } } message: { Text(LocalizedStringKey(store.errorMessage ?? "")) }
    }
    private func canResume(_ w: WatchConfiguration) -> Bool { [.paused, .triggered, .error].contains(w.status) }
    private func toggle(_ w: WatchConfiguration) { Task { if canResume(w) { await store.resume(w.id) } else { await store.pause(w.id) } } }
}
struct WatchDetailsView: View {
    @ObservedObject var store: WatchStore
    let watch: WatchConfiguration
    let edit: () -> Void
    let reselect: () -> Void
    var events: [WatchEvent] { store.data.events.filter { $0.watchID == watch.id } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) { Text(watch.name).font(.title2.bold()); StatusBadge(status: watch.status) }
                    Spacer()
                    Button(LocalizedStringKey([.paused,.triggered,.error].contains(watch.status) ? "Resume" : "Pause")) { Task { if [.paused,.triggered,.error].contains(watch.status) { await store.resume(watch.id) } else { await store.pause(watch.id) } } }
                    Button("Edit", action: edit)
                }
                PreviewImage(image: store.previews[watch.id]).frame(height: 210)
                if let message = store.sourceMessages[watch.id] { Label(LocalizedStringKey(message), systemImage: "info.circle").font(.callout).foregroundStyle(.secondary) }
                if watch.status == .permissionRequired {
                    Button("Open Screen Recording Settings") { PermissionService.openScreenSettings() }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("RULE").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    Text(LocalizedStringKey(watch.rule.mode.title)).font(.headline)
                    if !watch.rule.text.isEmpty { Text("“\(watch.rule.text)”").textSelection(.enabled) }
                    Text(store.format("Every %.1f s · %ld confirmations · %@", watch.rule.interval, watch.rule.confirmations, store.text(watch.rule.oneShot ? "One-shot" : "Continuous"))).font(.callout).foregroundStyle(.secondary)
                    Text(watch.source.name).font(.caption).foregroundStyle(.secondary)
                    Text(LocalizedStringKey(watch.source.kind == .display ? "This watch follows visible pixels in a fixed screen region." : "This watch follows the selected window. Restore it if minimized.")).font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                let d = store.diagnostics[watch.id] ?? Diagnostics()
                HStack(spacing: 24) {
                    metric("Checks", "\(d.successfulChecks)"); metric("Avg analysis", store.format("%.0f ms", d.averageMilliseconds)); metric("Frames skipped", "\(d.skippedFrames)"); metric("Capture retries", "\(d.captureErrors)")
                }
                if let date = watch.lastAnalysis { LabeledContent("Last successful check", value: store.dateText(date)).font(.caption).foregroundStyle(.secondary) }
                HStack { Button("Test Notification") { Task { await store.testNotification(watch.id) } }.disabled(!store.data.settings.notifications); Spacer(); Button("Select a new source", action: reselect) }
                Divider()
                Text("EVENT HISTORY").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                if events.isEmpty { Text("No events yet. PixelWatch is ready when you are.").font(.callout).foregroundStyle(.secondary) }
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(EventPresentation.reason(event, language: store.data.settings.language)).font(.callout).textSelection(.enabled)
                        if let previous = EventPresentation.previous(event, language: store.data.settings.language) { Text(store.format("Previous: %@", previous)).font(.caption).foregroundStyle(.secondary) }
                        if let current = EventPresentation.current(event, language: store.data.settings.language) { Text(store.format("New: %@", current)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                        Text(store.dateText(event.date)).font(.caption2).foregroundStyle(.tertiary)
                    }.padding(.vertical,6)
                }
            }.padding(24)
        }.frame(minWidth: 480,maxWidth: .infinity)
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading,spacing: 4) { Text(value).font(.headline.monospacedDigit()); Text(LocalizedStringKey(title)).font(.caption2).foregroundStyle(.secondary) }
    }
}
