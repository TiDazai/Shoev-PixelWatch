import Foundation

public struct AnalysisObservation: Sendable {
    public var signature: [Float]
    public var text: String?
    public var textReliable: Bool
    public var date: Date
    public init(signature: [Float], text: String? = nil, textReliable: Bool = false, date: Date = Date()) {
        self.signature = signature; self.text = text; self.textReliable = textReliable; self.date = date
    }
}
/// Stateful, deterministic rule evaluator. No capture, UI or notification dependencies.
public struct RuleEvaluationEngine: Sendable {
    private var baselineImage: [Float]?
    private var previousImage: [Float]?
    private var baselineText: String?
    private var candidateText: String?
    private var candidateCount = 0
    private var conditionCount = 0
    private var oppositeCount = 0
    private var presenceCount = 0
    private var presenceConfirmed = false
    private var armed = true
    private var stopped = false
    private var lastTrigger: Date?
    private var stableSince: Date?
    private var stableArmed = false
    public init() {}
    public mutating func unavailable() {
        conditionCount = 0; oppositeCount = 0; candidateCount = 0; candidateText = nil
        presenceCount = 0; stableSince = nil; stableArmed = false
        // A recovery establishes a new baseline; a gap must never look like a change.
        baselineImage = nil; previousImage = nil; baselineText = nil
        presenceConfirmed = false
    }
    public mutating func evaluate(_ o: AnalysisObservation, watch: WatchConfiguration) -> WatchEvent? {
        guard !stopped, !o.signature.isEmpty else { unavailable(); return nil }
        let rule = watch.rule.validated()
        if baselineImage == nil { baselineImage = o.signature; previousImage = o.signature; stableSince = o.date }
        let text = TextNormalization.normalize(o.text ?? "")
        var condition = false
        var previous: String?
        var current: String?
        var visualDifference: Double?
        switch rule.mode {
        case .visualChange:
            let score = ImageComparisonService.difference(baselineImage!, o.signature)
            visualDifference = score
            condition = score >= rule.visualThreshold
            previous = "Reference visual state"; current = String(format: "Visual difference: %.1f%%", score * 100)
        case .changeAfterStability:
            let step = ImageComparisonService.difference(previousImage ?? o.signature, o.signature)
            if step < rule.visualThreshold {
                if stableSince == nil { stableSince = o.date }
                if o.date.timeIntervalSince(stableSince!) >= rule.stabilityDuration && !stableArmed {
                    baselineImage = o.signature; stableArmed = true
                }
            } else if !stableArmed { stableSince = o.date }
            visualDifference = ImageComparisonService.difference(baselineImage!, o.signature)
            condition = stableArmed && visualDifference! >= rule.visualThreshold
            previous = "Reference visual state"
        case .textAppears, .textDisappears:
            guard o.textReliable, !text.isEmpty else { conditionCount = 0; presenceCount = 0; oppositeCount = 0; return nil }
            let present = TextNormalization.matches(text, target: rule.text, full: rule.fullMatch)
            if present { presenceCount += 1; if presenceCount >= rule.confirmations { presenceConfirmed = true } }
            else { presenceCount = 0 }
            condition = rule.mode == .textAppears ? present : (presenceConfirmed && !present)
            previous = rule.mode == .textDisappears ? rule.text : "Target text not detected"
            current = o.text
        case .textChanges:
            guard o.textReliable, !text.isEmpty else { candidateCount = 0; candidateText = nil; conditionCount = 0; return nil }
            if candidateText == text { candidateCount += 1 } else { candidateText = text; candidateCount = 1 }
            if baselineText == nil, candidateCount >= rule.confirmations { baselineText = text }
            condition = baselineText != nil && text != baselineText && candidateCount >= rule.confirmations
            previous = baselineText; current = o.text
        }
        previousImage = o.signature
        if !condition {
            conditionCount = 0; oppositeCount += 1
            if oppositeCount >= rule.confirmations { armed = true }
            return nil
        }
        oppositeCount = 0
        conditionCount += 1
        // Text changes already has candidate stabilization; other modes debounce here.
        let confirmed = rule.mode == .textChanges || conditionCount >= rule.confirmations
        guard confirmed, armed, lastTrigger.map({ o.date.timeIntervalSince($0) >= rule.cooldown }) ?? true else { return nil }
        lastTrigger = o.date; armed = false; stopped = rule.oneShot; conditionCount = 0
        let reason: String
        switch rule.mode {
        case .visualChange: reason = "The selected area has changed."
        case .changeAfterStability: reason = "The area changed after a stable period."
        case .textAppears: reason = "\"\(rule.text)\" appeared in your watched area."
        case .textDisappears: reason = "\"\(rule.text)\" disappeared from your watched area."
        case .textChanges: reason = "Text changed from \"\(baselineText ?? "")\" to \"\(text)\"."
        }
        if rule.mode == .textChanges { baselineText = text; armed = true }
        if [.visualChange, .changeAfterStability].contains(rule.mode), !rule.compareOriginal {
            baselineImage = o.signature
        }
        if rule.mode == .changeAfterStability { stableArmed = false; stableSince = o.date }
        return WatchEvent(watchID: watch.id, date: o.date, reason: reason, previous: previous, current: current, mode: rule.mode, target: rule.text, visualDifference: visualDifference)
    }
}
