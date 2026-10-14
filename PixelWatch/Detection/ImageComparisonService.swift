import Foundation
import CoreGraphics
import Accelerate

public enum ImageComparisonService {
    public static func signature(_ image: CGImage) -> [Float] {
        let side = 64
        var pixels = [UInt8](repeating: 0, count: side * side)
        let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return success ? pixels.map { Float($0) / 255 } : []
    }
    public static func difference(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 1 }
        var delta = [Float](repeating: 0, count: lhs.count)
        vDSP_vsub(lhs, 1, rhs, 1, &delta, 1, vDSP_Length(lhs.count))
        // A per-pixel dead band removes small colour changes and antialiasing noise.
        for i in delta.indices { delta[i] = max(0, abs(delta[i]) - 0.025) }
        var mean: Float = 0
        vDSP_meanv(delta, 1, &mean, vDSP_Length(delta.count))
        return Double(mean)
    }
}
