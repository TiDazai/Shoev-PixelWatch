import Foundation
import Vision
import CoreGraphics
public struct OCRResult: Sendable {
    public let text: String
    public let reliable: Bool
}
public enum OCRService {
    /// Call from a worker task. Empty or mixed low-confidence results are inconclusive.
    public static func recognize(_ image: CGImage) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["en-US", "ru-RU"].filter { supported.contains($0) }
        try VNImageRequestHandler(cgImage: image).perform([request])
        let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
        let reliable = !candidates.isEmpty && candidates.allSatisfy { $0.confidence >= 0.55 }
        return OCRResult(text: candidates.map(\.string).joined(separator: "\n"), reliable: reliable)
    }
}
