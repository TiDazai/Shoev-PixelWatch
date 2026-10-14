import Foundation

public enum WatchMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case visualChange, textAppears, textDisappears, textChanges, changeAfterStability
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .visualChange: return "Any Visual Change"
        case .textAppears: return "Text Appears"
        case .textDisappears: return "Text Disappears"
        case .textChanges: return "Text Changes"
        case .changeAfterStability: return "Visual Change After Stability"
        }
    }
    public var usesText: Bool { [.textAppears, .textDisappears, .textChanges].contains(self) }
}
public enum WatchStatus: String, Codable, Sendable {
    case active = "Active", paused = "Paused", triggered = "Triggered"
    case waitingForSource = "Waiting for source", permissionRequired = "Permission required", error = "Error"
}
public struct Region: Codable, Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double = 0, y: Double = 0, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var isValid: Bool { [x,y,width,height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && width >= 8 && height >= 8 }
}
public struct CaptureSource: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case display, window }
    public var kind: Kind
    public var id: UInt32
    public var name: String
    public var bundleID: String?
    public var displayUUID: String?
    public var processID: Int32?
    public var region: Region
    public var referenceWidth: Double
    public var referenceHeight: Double
    public init(kind: Kind, id: UInt32, name: String, region: Region, bundleID: String? = nil, displayUUID: String? = nil, referenceWidth: Double = 0, referenceHeight: Double = 0, processID: Int32? = nil) {
        self.kind = kind; self.id = id; self.name = name; self.region = region; self.bundleID = bundleID; self.displayUUID = displayUUID
        self.processID = processID
        self.referenceWidth = referenceWidth; self.referenceHeight = referenceHeight
    }
}
public struct WatchRule: Codable, Equatable, Sendable {
    public var mode: WatchMode = .visualChange
    public var text: String = ""
    public var fullMatch = false
    public var sensitivity: Double = 0.65
    public var interval: Double = 2
    public var confirmations: Int = 2
    public var cooldown: Double = 30
    public var oneShot = true
    public var compareOriginal = false
    public var stabilityDuration: Double = 6
    public init() {}
    public var visualThreshold: Double { 0.005 + (1 - sensitivity) * 0.18 }
    public func validated() -> WatchRule {
        var r = self
        r.sensitivity = sensitivity.isFinite ? min(1,max(0,sensitivity)) : 0.65
        r.interval = interval.isFinite ? min(300,max(0.5,interval)) : 2
        r.confirmations = min(20,max(2,confirmations))
        r.cooldown = cooldown.isFinite ? min(86400,max(0,cooldown)) : 30
        r.stabilityDuration = stabilityDuration.isFinite ? min(600,max(2,stabilityDuration)) : 6
        return r
    }
}
public struct WatchConfiguration: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var source: CaptureSource
    public var rule: WatchRule
    public var status: WatchStatus = .active
    public var createdAt = Date()
    public var lastAnalysis: Date?
    public var lastChange: Date?
    public init(name: String, source: CaptureSource, rule: WatchRule = WatchRule()) {
        self.name = name; self.source = source; self.rule = rule.validated()
    }
}
public struct WatchEvent: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var watchID: UUID
    public var date: Date
    public var reason: String
    public var previous: String?
    public var current: String?
    public var mode: WatchMode? = nil
    public var target: String? = nil
    public var visualDifference: Double? = nil
}
public struct AppSettings: Codable, Equatable, Sendable {
    public var startMinimized = false
    public var notifications = true
    public var sound = true
    public var onboardingComplete = false
    public var language = "ru"
    public var menuShowsCount = true
    public var defaults = WatchRule()
    public init() {}
}
public struct Diagnostics: Sendable {
    public var successfulChecks = 0
    public var skippedFrames = 0
    public var captureErrors = 0
    public var totalAnalysisSeconds: Double = 0
    public var averageMilliseconds: Double { successfulChecks == 0 ? 0 : totalAnalysisSeconds / Double(successfulChecks) * 1000 }
    public init() {}
}
