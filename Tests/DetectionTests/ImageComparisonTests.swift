import XCTest
import Foundation
#if PACKAGE_CORE
@testable import PixelWatchCore
#else
@testable import PixelWatch
#endif

import CoreGraphics
final class ImageComparisonTests: XCTestCase {
    func fixture(_ value: CGFloat, patch: Bool = false) -> CGImage {
        let ctx = CGContext(data:nil,width:128,height:128,bitsPerComponent:8,bytesPerRow:128,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray:value,alpha:1); ctx.fill(CGRect(x:0,y:0,width:128,height:128))
        if patch { ctx.setFillColor(gray:1,alpha:1); ctx.fill(CGRect(x:40,y:40,width:64,height:64)) }
        return ctx.makeImage()!
    }
    func testIdenticalImages() {
        let a = ImageComparisonService.signature(fixture(0.4))
        XCTAssertEqual(ImageComparisonService.difference(a,a),0)
    }
    func testMinorColourNoiseIgnored() {
        let a = ImageComparisonService.signature(fixture(0.40)), b = ImageComparisonService.signature(fixture(0.41))
        XCTAssertLessThan(ImageComparisonService.difference(a,b),0.005)
    }
    func testRealPatchDetected() {
        let a = ImageComparisonService.signature(fixture(0.2)), b = ImageComparisonService.signature(fixture(0.2,patch:true))
        XCTAssertGreaterThan(ImageComparisonService.difference(a,b),0.1)
    }
    func testInvalidSignatureIsInconclusiveToEngine() {
        var e = RuleEvaluationEngine()
        let w = WatchConfiguration(name:"Test",source:CaptureSource(kind:.display,id:1,name:"Fixture",region:Region(width:100,height:100)))
        XCTAssertNil(e.evaluate(AnalysisObservation(signature:[]),watch:w))
    }
}
