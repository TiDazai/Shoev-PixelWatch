import Foundation
public enum RegionGeometry {
    public static func fromGlobalAppKit(_ selection: CGRect, displayFrame: CGRect) -> Region? {
        let local = selection.offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY)
        return fromLocalAppKit(local, displaySize: displayFrame.size)
    }
    public static func fromLocalAppKit(_ selection: CGRect, displaySize: CGSize) -> Region? {
        guard selection.width.isFinite, selection.height.isFinite, selection.minX.isFinite, selection.minY.isFinite else { return nil }
        let clipped = selection.standardized.intersection(CGRect(origin: .zero, size: displaySize))
        let region = Region(x: clipped.minX, y: displaySize.height - clipped.maxY, width: clipped.width, height: clipped.height)
        return region.isValid ? region : nil
    }
    public static func pixelSize(width: Double, height: Double, scale: Double, limit: Double = 2048) -> (width: Int, height: Int) {
        guard width.isFinite, height.isFinite, width > 0, height > 0, scale.isFinite, scale > 0 else { return (8,8) }
        let factor = min(scale, limit / max(width,height))
        return (max(8,Int(width*factor)),max(8,Int(height*factor)))
    }
}
