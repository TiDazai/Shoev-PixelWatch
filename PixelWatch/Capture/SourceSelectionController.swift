import AppKit
@preconcurrency import ScreenCaptureKit

@MainActor final class SourceSelectionController: NSObject, SCContentSharingPickerObserver, ObservableObject {
    private let capture: CaptureService
    private let area = AreaSelectionController()
    private var kind = CaptureSource.Kind.display
    private var completion: ((CaptureSource, SCContentFilter, CGImage?) -> Void)?
    var language = "ru"
    var onCancel: (() -> Void)?
    var onError: ((String) -> Void)?
    init(capture: CaptureService) {
        self.capture = capture; super.init(); SCContentSharingPicker.shared.add(self)
    }
    func choose(_ kind: CaptureSource.Kind, completion: @escaping (CaptureSource, SCContentFilter, CGImage?) -> Void) {
        self.kind = kind; self.completion = completion
        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = kind == .display ? .singleDisplay : .singleWindow
        config.excludedBundleIDs = [Bundle.main.bundleIdentifier ?? "systems.shoev.pixelwatch"]
        config.allowsChangingSelectedContent = false
        let picker = SCContentSharingPicker.shared
        picker.configuration = config; picker.isActive = true
        picker.present(using: kind == .display ? .display : .window)
    }
    private func makeDisplaySource(_ display: SCDisplay) -> CaptureSource {
        let uuid = CGDisplayCreateUUIDFromDisplayID(display.displayID).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
        let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID }
        return CaptureSource(kind: .display, id: display.displayID, name: screen?.localizedName ?? L10n.format("Display %u", display.displayID, language: language), region: Region(width: Double(display.width), height: Double(display.height)), displayUUID: uuid, referenceWidth: Double(display.width), referenceHeight: Double(display.height))
    }
    private func makeWindowSource(_ window: SCWindow) -> CaptureSource {
        CaptureSource(kind: .window, id: window.windowID, name: "\(window.owningApplication?.applicationName ?? L10n.text("Application", language: language)) — \(window.title ?? L10n.text("Window", language: language))", region: Region(width: window.frame.width, height: window.frame.height), bundleID: window.owningApplication?.bundleIdentifier, processID: window.owningApplication?.processID)
    }
    private func selected(_ source: CaptureSource, filter: SCContentFilter) {
        if source.kind == .display {
            area.select(displayID: source.id, language: language) { [weak self] region in
                guard let self else { return }; guard let region else { self.onCancel?(); return }
                var s = source; s.region = region
                self.finish(s, filter: filter)
            }
        } else { finish(source, filter: filter) }
    }
    private func finish(_ source: CaptureSource, filter: SCContentFilter) {
        Task { @MainActor in
            do {
                let preview = try await capture.preview(source: source, filter: filter)
                completion?(source, filter, preview); completion = nil
            } catch { onError?(L10n.format("Could not preview the source: %@", error.localizedDescription, language: language)) }
        }
    }
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in self.completion = nil; self.onCancel?() }
    }
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            guard self.completion != nil else { return }
            if self.kind == .display, let display = filter.includedDisplays.first { self.selected(self.makeDisplaySource(display), filter: filter) }
            else if let window = filter.includedWindows.first { self.selected(self.makeWindowSource(window), filter: filter) }
            else { self.onError?("Select one display or one application window.") }
        }
    }
    nonisolated func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in self.onError?(error.localizedDescription) }
    }
}
