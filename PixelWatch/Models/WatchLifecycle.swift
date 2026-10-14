import Foundation

public enum WatchTransition: Sendable {
    case pause, resume, sourceUnavailable, permissionMissing, analysisSucceeded, trigger(oneShot: Bool), failure
}
public extension WatchStatus {
    func transitioning(_ transition: WatchTransition) -> WatchStatus {
        switch transition {
        case .pause: return .paused
        case .resume: return .active
        case .sourceUnavailable: return [.paused, .triggered, .error].contains(self) ? self : .waitingForSource
        case .permissionMissing: return [.paused, .triggered, .error].contains(self) ? self : .permissionRequired
        case .analysisSucceeded: return [.paused, .triggered, .error].contains(self) ? self : .active
        case .trigger(let oneShot): return self == .active && oneShot ? .triggered : self
        case .failure: return .error
        }
    }
}
