import AppKit
import ScreenCaptureKit

@MainActor final class MonitoringCoordinator {
    private weak var store: WatchStore?
    private var task: Task<Void, Never>?
    private var engines: [UUID: RuleEvaluationEngine] = [:]
    private var textCache: [UUID: (sequence: UInt64, result: OCRResult)] = [:]
    private var due: [UUID: Date] = [:]
    private var generation: [UUID: Int] = [:]
    private var tokens: [NSObjectProtocol] = []
    private var suspensionReasons: Set<String> = []
    init(store: WatchStore) { self.store = store }
    func start() {
        guard task == nil else { return }
        let center = NSWorkspace.shared.notificationCenter
        for (name, reason, suspended) in [
            (NSWorkspace.willSleepNotification, "sleep", true), (NSWorkspace.didWakeNotification, "sleep", false),
            (NSWorkspace.screensDidSleepNotification, "display", true), (NSWorkspace.screensDidWakeNotification, "display", false)
        ] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.setSuspended(reason, suspended) }
            })
        }
        let distributed = DistributedNotificationCenter.default()
        for (name, suspended) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            tokens.append(distributed.addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.setSuspended("lock", suspended) }
            })
        }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                let idle = self?.store?.activeCount == 0 || !(self?.suspensionReasons.isEmpty ?? true)
                try? await Task.sleep(for: idle ? .seconds(2) : .milliseconds(250))
            }
        }
    }
    func setSuspended(_ reason: String, _ suspended: Bool) async {
        if suspended { suspensionReasons.insert(reason) } else { suspensionReasons.remove(reason) }
        guard let store else { return }
        if suspended {
            for w in store.data.watches where [.active, .waitingForSource, .permissionRequired].contains(w.status) {
                setStatus(w.id, .waitingForSource, message: "Monitoring resumes when the Mac and source are available.")
                generation[w.id, default: 0] += 1
            }
            engines.removeAll(); textCache.removeAll(); due.removeAll(); await store.capture.stopAll()
        }
    }
    func reset(_ id: UUID) async {
        generation[id, default: 0] += 1; engines[id] = nil; textCache[id] = nil; due[id] = nil
        await store?.capture.release(id)
    }
    func shutdown() async {
        task?.cancel(); task = nil
        for id in engines.keys { generation[id, default: 0] += 1 }
        engines.removeAll(); textCache.removeAll()
        for token in tokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            DistributedNotificationCenter.default().removeObserver(token)
        }
        tokens.removeAll(); await store?.capture.stopAll()
    }
    private func setStatus(_ id: UUID, _ status: WatchStatus, message: String? = nil) {
        guard let store, let i = store.data.watches.firstIndex(where: { $0.id == id }) else { return }
        if store.data.watches[i].status != status { store.data.watches[i].status = status; store.persist() }
        store.sourceMessages[id] = message
    }
    private func tick() async {
        guard suspensionReasons.isEmpty, let store else { return }
        let now = Date()
        let ready = store.data.watches.filter { [.active, .waitingForSource, .permissionRequired].contains($0.status) && (due[$0.id] ?? .distantPast) <= now }
        guard !ready.isEmpty else { return }
        store.screenAllowed = PermissionService.screenAllowed
        // Picker-granted filters authorize this session even without a persistent TCC grant.
        let permitted = ready.filter { !store.capture.deniedSourceIDs.contains($0.id) && (store.screenAllowed || store.capture.pickerFilters[$0.id] != nil) }
        for watch in ready where !permitted.contains(where: { $0.id == watch.id }) {
            engines[watch.id]?.unavailable(); textCache[watch.id] = nil; setStatus(watch.id, .permissionRequired, message: "Allow Screen Recording, or use Select a new source in this watch’s details.")
            due[watch.id] = now.addingTimeInterval(3); await store.capture.release(watch.id)
        }
        guard !permitted.isEmpty else { return }
        let content: SCShareableContent
        do { content = try await store.capture.content() }
        catch {
            for w in permitted {
                engines[w.id]?.unavailable(); textCache[w.id] = nil; setStatus(w.id, store.screenAllowed ? .waitingForSource : .permissionRequired, message: "Screen capture is unavailable. Check permission and re-select the source.")
                due[w.id] = now.addingTimeInterval(3); await store.capture.release(w.id)
            }
            return
        }
        for watch in permitted {
            let id = watch.id, version = generation[watch.id, default: 0]
            due[id] = Date().addingTimeInterval(watch.rule.interval)
            guard suspensionReasons.isEmpty, let existing = store.data.watches.first(where: { $0.id == id }), [.active, .waitingForSource, .permissionRequired].contains(existing.status) else { continue }
            do {
                try store.capture.validateSource(watch, content: content)
                let session = try await store.capture.acquire(watch, content: content)
                guard generation[id, default: 0] == version, suspensionReasons.isEmpty else { await store.capture.release(id); continue }
                let frame = try session.frame()
                let began = Date()
                let cachedText = textCache[id]
                let (observation, recognized) = try await Task.detached(priority: .utility) {
                    let signature = ImageComparisonService.signature(frame.image)
                    // Uniform black is inconclusive: protected content often arrives this way.
                    guard let maxValue = signature.max(), maxValue > 0.015 else { throw CaptureFailure(message: "The source is blank or protected. No condition was evaluated.") }
                    let text: OCRResult?
                    if !watch.rule.mode.usesText { text = nil }
                    else if let cachedText, cachedText.sequence == frame.sequence { text = cachedText.result }
                    else { text = try OCRService.recognize(frame.image) }
                    return (AnalysisObservation(signature: signature, text: text?.text, textReliable: text?.reliable ?? false, date: Date()), text)
                }.value
                guard generation[id, default: 0] == version, suspensionReasons.isEmpty,
                      let i = store.data.watches.firstIndex(where: { $0.id == id }), [.active, .waitingForSource, .permissionRequired].contains(store.data.watches[i].status) else { continue }
                if let recognized, recognized.reliable { textCache[id] = (frame.sequence,recognized) }
                store.previews[id] = frame.image
                var d = store.diagnostics[id] ?? Diagnostics()
                d.successfulChecks += 1; d.totalAnalysisSeconds += Date().timeIntervalSince(began); d.skippedFrames = session.dropped
                store.diagnostics[id] = d
                var engine = engines[id] ?? RuleEvaluationEngine()
                let event = engine.evaluate(observation, watch: watch)
                engines[id] = engine
                store.data.watches[i].lastAnalysis = observation.date
                store.data.watches[i].status = store.data.watches[i].status.transitioning(.analysisSucceeded)
                store.sourceMessages[id] = watch.rule.mode.usesText && !observation.textReliable ? "OCR is inconclusive; waiting for readable text." : nil
                if let event {
                    store.data.events.insert(event, at: 0)
                    if store.data.events.count > 500 { store.data.events.removeLast(store.data.events.count - 500) }
                    store.data.watches[i].lastChange = event.date
                    if watch.rule.oneShot { store.data.watches[i].status = store.data.watches[i].status.transitioning(.trigger(oneShot: true)); await store.capture.release(id) }
                    do { try await store.notifications.send(event: event, name: watch.name, settings: store.data.settings) }
                    catch { store.errorMessage = "The event was recorded, but its notification could not be delivered." }
                    store.persist()
                }
            } catch {
                guard generation[id, default: 0] == version else { continue }
                engines[id]?.unavailable(); textCache[id] = nil
                var d = store.diagnostics[id] ?? Diagnostics(); d.captureErrors += 1; store.diagnostics[id] = d
                let kind = (error as? CaptureFailure)?.kind
                if kind == .userStopped { setStatus(id, .paused, message: error.localizedDescription) }
                else if kind == .permissionRequired {
                    store.capture.deniedSourceIDs.insert(id)
                    store.capture.pickerFilters[id] = nil
                    setStatus(id, .permissionRequired, message: error.localizedDescription)
                } else { setStatus(id, .waitingForSource, message: error.localizedDescription) }
                await store.capture.release(id)
                due[id] = Date().addingTimeInterval(max(3, watch.rule.interval))
            }
        }
    }
}
