import XCTest
import Foundation
#if PACKAGE_CORE
@testable import PixelWatchCore
#else
@testable import PixelWatch
#endif

import AppKit
final class OCRServiceTests: XCTestCase {
    func image(_ text: String) -> CGImage {
        let ctx = CGContext(data:nil,width:800,height:180,bitsPerComponent:8,bytesPerRow:3200,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(gray:1,alpha:1)); ctx.fill(CGRect(x:0,y:0,width:800,height:180))
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext:ctx,flipped:false)
        (text as NSString).draw(at:CGPoint(x:30,y:60),withAttributes:[.font:NSFont.systemFont(ofSize:56,weight:.medium),.foregroundColor:NSColor.black])
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()!
    }
    func testLocalVisionRecognizesEnglishFixture() throws {
        let result = try OCRService.recognize(image("Processing Completed"))
        XCTAssertTrue(result.reliable); XCTAssertTrue(TextNormalization.normalize(result.text).contains("completed"))
    }
    func testLocalVisionRecognizesRussianFixture() throws {
        let result = try OCRService.recognize(image("Заявка одобрена"))
        XCTAssertTrue(TextNormalization.normalize(result.text).contains("одобрена"))
    }
    func testBlankIsInconclusive() throws {
        let result = try OCRService.recognize(image("")); XCTAssertTrue(result.text.isEmpty); XCTAssertFalse(result.reliable)
    }
}
