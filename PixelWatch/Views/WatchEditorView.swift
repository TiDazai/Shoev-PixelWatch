import SwiftUI
import ScreenCaptureKit
struct WatchEditorView: View {
    @ObservedObject var store: WatchStore
    @State var watch: WatchConfiguration
    var filter: SCContentFilter?
    var preview: CGImage?
    var existing = false
    var onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Image(systemName: "viewfinder").foregroundStyle(Design.accent); Text(LocalizedStringKey(existing ? "Edit Watch" : "New Watch")).font(.title2.bold()) }
            PreviewImage(image: preview ?? store.previews[watch.id]).frame(height: 150)
            Form {
                TextField("Name", text: $watch.name)
                LabeledContent("Source", value: watch.source.name)
                RuleFields(rule: $watch.rule)
            }.formStyle(.grouped)
            Text(LocalizedStringKey(watch.source.kind == .display ? "Screen Region follows visible pixels. Another window covering this area will change what PixelWatch sees." : "Window Mode follows this window when it moves. Minimized, closed or protected windows may be unavailable.")).font(.caption).foregroundStyle(.secondary)
            if !existing { Text("Allow notifications after starting to receive alerts. Events also appear in your dashboard.").font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("Cancel") { dismiss(); onClose?() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(LocalizedStringKey(existing ? "Save" : "Start Watching")) {
                    watch.rule = watch.rule.validated()
                    Task {
                        if existing {
                            if let filter { store.capture.pickerFilters[watch.id] = filter; store.capture.deniedSourceIDs.remove(watch.id) }
                            if let preview { store.previews[watch.id] = preview }
                            await store.update(watch)
                        }
                        else { store.add(watch, filter: filter, preview: preview) }
                        dismiss(); onClose?()
                        if !existing && store.data.settings.notifications && store.notifications.authorization == .notDetermined { await store.requestNotifications() }
                    }
                }.buttonStyle(.borderedProminent).foregroundStyle(Design.actionText).keyboardShortcut(.defaultAction)
                    .disabled(watch.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ([.textAppears,.textDisappears].contains(watch.rule.mode) && TextNormalization.normalize(watch.rule.text).isEmpty))
            }
        }.padding(24).frame(width: 540, height: 700).tint(Design.accent).background(Design.background)
    }
}
