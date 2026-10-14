import AppKit
@preconcurrency import ScreenCaptureKit
import CoreImage
import CoreMedia

struct CaptureFailure: LocalizedError {
    enum Kind { case unavailable, userStopped, permissionRequired }
    let message: String
    var kind: Kind = .unavailable
    var errorDescription: String? { message }
}
struct CapturedFrame: @unchecked Sendable {
    let image: CGImage
    let sequence: UInt64
}
protocol CaptureProvider: AnyObject {
    func frame() throws -> CapturedFrame
    @MainActor func stop() async
}
/// Only the latest complete frame is retained. Conversion stays on the capture queue.
final class CaptureSession: NSObject, SCStreamOutput, SCStreamDelegate, CaptureProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var image: CGImage?
    private var sequence: UInt64 = 0
    private var heartbeat: Date?
    private var failure: CaptureFailure?
    @MainActor private var stream: SCStream?
    @MainActor private var configuration: SCStreamConfiguration?
    private var stopped = false
    private var discarded = 0
    private var consumed = true
    var maximumFrameAge: Double = 8
    let queue = DispatchQueue(label: "systems.shoev.pixelwatch.capture", qos: .utility)
    var dropped: Int { lock.withLock { discarded } }
    @MainActor func start(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws {
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        self.stream = stream; self.configuration = configuration
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        do { try await stream.startCapture() }
        catch {
            recordStop(error); try? stream.removeStreamOutput(self, type: .screen)
            self.stream = nil; self.configuration = nil
            throw lock.withLock { failure ?? CaptureFailure(message: "Capture could not start.") }
        }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        accept(sampleBuffer)
    }
    func accept(_ sampleBuffer: CMSampleBuffer) {
        guard sampleBuffer.isValid,
              let attachment = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusNumber = attachment.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: statusNumber) else {
            lock.withLock { image = nil; heartbeat = nil; discarded += 1 }; return
        }
        if status == .idle { lock.withLock { if !stopped { heartbeat = Date() } }; return }
        guard status == .complete, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            lock.withLock { image = nil; heartbeat = nil; discarded += 1 }; return
        }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            lock.withLock { image = nil; heartbeat = nil; discarded += 1 }; return
        }
        lock.withLock {
            guard !stopped else { return }
            if image != nil && !consumed { discarded += 1 }
            consumed = false
            image = cgImage; sequence &+= 1; heartbeat = Date()
        }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        recordStop(error)
    }
    func recordStop(_ error: Error) {
        let nsError = error as NSError
        let kind: CaptureFailure.Kind
        if nsError.domain == SCStreamErrorDomain && nsError.code == SCStreamError.Code.userStopped.rawValue { kind = .userStopped }
        else if nsError.domain == SCStreamErrorDomain && nsError.code == SCStreamError.Code.userDeclined.rawValue { kind = .permissionRequired }
        else { kind = .unavailable }
        lock.withLock {
            failure = CaptureFailure(message: kind == .userStopped ? "Screen sharing was stopped. Resume explicitly to start again." : "Capture stopped. Check permission and re-select the source if necessary.", kind: kind)
            image = nil; heartbeat = nil
        }
    }
    func frame() throws -> CapturedFrame {
        try lock.withLock {
            if let failure { throw failure }
            guard !stopped, let image, let heartbeat, Date().timeIntervalSince(heartbeat) < maximumFrameAge else {
                throw CaptureFailure(message: "No available frame. The source may be sleeping, minimized or protected.")
            }
            consumed = true
            return CapturedFrame(image: image, sequence: sequence)
        }
    }
    @MainActor func stop() async {
        lock.withLock { stopped = true; image = nil; heartbeat = nil }
        if let stream { try? await stream.stopCapture(); try? stream.removeStreamOutput(self, type: .screen) }
        stream = nil; configuration = nil
    }
    @MainActor func resize(width: Int, height: Int) async throws {
        guard let stream, let configuration else { return }
        configuration.width = width; configuration.height = height
        try await stream.updateConfiguration(configuration)
    }
}

@MainActor final class CaptureService {
    struct Entry { let session: CaptureSession; var owners: Set<UUID>; var geometry: CGSize }
    private var sessions: [String: Entry] = [:]
    private var keys: [UUID: String] = [:]
    var deniedSourceIDs: Set<UUID> = []
    var pickerFilters: [UUID: SCContentFilter] = [:]
    func content() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
    }
    func sourceKey(_ watch: WatchConfiguration) -> String {
        let s = watch.source, r = s.region
        return "\(s.kind.rawValue):\(s.id):\(r.x):\(r.y):\(r.width):\(r.height):\(watch.rule.interval)"
    }
    func acquire(_ watch: WatchConfiguration, content: SCShareableContent) async throws -> CaptureSession {
        try validateSource(watch, content: content)
        let key = sourceKey(watch)
        if var entry = sessions[key] {
            if watch.source.kind == .window, let window = content.windows.first(where: { $0.windowID == watch.source.id }) {
                let updatedFilter = SCContentFilter(desktopIndependentWindow: window)
                let geometry = updatedFilter.contentRect.size
                if geometry != entry.geometry {
                    let size = RegionGeometry.pixelSize(width: geometry.width, height: geometry.height, scale: Double(updatedFilter.pointPixelScale))
                    try await entry.session.resize(width: size.width, height: size.height)
                    entry.geometry = geometry
                }
            }
            entry.owners.insert(watch.id); sessions[key] = entry; keys[watch.id] = key
            return entry.session
        }
        let source = watch.source
        let filter: SCContentFilter
        var width: Double, height: Double
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = false
        configuration.captureMicrophone = false
        configuration.showsCursor = false
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.minimumFrameInterval = CMTime(seconds: watch.rule.interval, preferredTimescale: 600)
        configuration.ignoreShadowsSingleWindow = true
        if source.kind == .display {
            let display = try resolveDisplay(source, content: content)
            width = source.region.width; height = source.region.height
            guard source.region.isValid,
                  source.region.x + width <= Double(display.width) + 1,
                  source.region.y + height <= Double(display.height) + 1,
                  source.referenceWidth == 0 || (abs(source.referenceWidth - Double(display.width)) < 1 && abs(source.referenceHeight - Double(display.height)) < 1) else {
                throw CaptureFailure(message: "Display geometry changed. Edit this watch and select its area again.")
            }
            let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            filter = PermissionService.screenAllowed ? SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: []) : (pickerFilters[watch.id] ?? SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: []))
            configuration.sourceRect = CGRect(x: source.region.x, y: source.region.y, width: width, height: height)
        } else {
            guard let window = content.windows.first(where: { $0.windowID == source.id && $0.owningApplication?.bundleIdentifier == source.bundleID && (source.processID == nil || $0.owningApplication?.processID == source.processID) }), window.isOnScreen else {
                throw CaptureFailure(message: "The selected window is unavailable. Restore it or select a new source.")
            }
            filter = PermissionService.screenAllowed ? SCContentFilter(desktopIndependentWindow: window) : (pickerFilters[watch.id] ?? SCContentFilter(desktopIndependentWindow: window))
            width = filter.contentRect.width; height = filter.contentRect.height
        }
        let scale = Double(filter.pointPixelScale)
        // Crop in points, deliver at Retina density, cap the longest edge to 2048 pixels.
        let size = RegionGeometry.pixelSize(width: width, height: height, scale: max(1,scale))
        configuration.width = size.width
        configuration.height = size.height
        let session = CaptureSession()
        session.maximumFrameAge = max(8, watch.rule.interval * 3)
        try await session.start(filter: filter, configuration: configuration)
        // Wait for the initial frame without recreating the stream every check.
        for _ in 0..<20 {
            if (try? session.frame()) != nil { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        sessions[key] = Entry(session: session, owners: [watch.id], geometry: CGSize(width: width, height: height)); keys[watch.id] = key
        return session
    }
    func resolveDisplay(_ source: CaptureSource, content: SCShareableContent) throws -> SCDisplay {
        guard let display = content.displays.first(where: {
            if let uuid = source.displayUUID, let displayUUID = CGDisplayCreateUUIDFromDisplayID($0.displayID)?.takeRetainedValue() {
                return CFUUIDCreateString(nil, displayUUID) as String == uuid
            }
            return $0.displayID == source.id
        }), CGDisplayIsActive(display.displayID) != 0, CGDisplayIsAsleep(display.displayID) == 0 else {
            throw CaptureFailure(message: "The display is disconnected or asleep.")
        }
        return display
    }
    func validateSource(_ watch: WatchConfiguration, content: SCShareableContent) throws {
        let source = watch.source
        if source.kind == .display {
            let display = try resolveDisplay(source, content: content)
            let r = source.region
            guard r.isValid, r.x + r.width <= Double(display.width) + 1, r.y + r.height <= Double(display.height) + 1,
                  source.referenceWidth == 0 || (abs(source.referenceWidth - Double(display.width)) < 1 && abs(source.referenceHeight - Double(display.height)) < 1) else {
                throw CaptureFailure(message: "Display geometry changed. Select a new source for this watch.")
            }
        } else {
            guard let window = content.windows.first(where: { $0.windowID == source.id && $0.owningApplication?.bundleIdentifier == source.bundleID && (source.processID == nil || $0.owningApplication?.processID == source.processID) }), window.isOnScreen, window.frame.width >= 8, window.frame.height >= 8 else {
                throw CaptureFailure(message: "Source unavailable. Restore the selected window or select its replacement.")
            }
        }
    }
    func release(_ id: UUID) async {
        guard let key = keys.removeValue(forKey: id), var entry = sessions[key] else { return }
        entry.owners.remove(id)
        if entry.owners.isEmpty { sessions.removeValue(forKey: key); await entry.session.stop() }
        else { sessions[key] = entry }
    }
    func stopAll() async {
        let old = sessions.values.map(\.session)
        sessions.removeAll(); keys.removeAll()
        for session in old { await session.stop() }
    }
    func preview(source: CaptureSource, filter: SCContentFilter) async throws -> CGImage {
        let c = SCStreamConfiguration()
        c.capturesAudio = false; c.showsCursor = false; c.ignoreShadowsSingleWindow = true
        let r = source.region
        if source.kind == .display { c.sourceRect = CGRect(x: r.x, y: r.y, width: r.width, height: r.height) }
        let w = source.kind == .display ? r.width : filter.contentRect.width
        let h = source.kind == .display ? r.height : filter.contentRect.height
        guard w.isFinite, h.isFinite, w >= 8, h >= 8 else { throw CaptureFailure(message: "The selected area is unavailable.") }
        let size = RegionGeometry.pixelSize(width: w, height: h, scale: Double(filter.pointPixelScale), limit: 1600)
        c.width = size.width; c.height = size.height
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: c)
    }
}
