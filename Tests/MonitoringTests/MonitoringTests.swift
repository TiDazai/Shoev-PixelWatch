import XCTest
import Foundation
#if PACKAGE_CORE
@testable import PixelWatchCore
#else
@testable import PixelWatch
#endif

final class MonitoringTests: XCTestCase {
    struct MockCaptureProvider {
        var frames: [AnalysisObservation?]
        mutating func next() -> AnalysisObservation? { frames.isEmpty ? nil : frames.removeFirst() }
    }
    func testCaptureGapDoesNotBecomeEvent() {
        let source = CaptureSource(kind:.display,id:1,name:"Mock",region:Region(width:100,height:100))
        let watch = WatchConfiguration(name:"Mock",source:source)
        var provider = MockCaptureProvider(frames:[AnalysisObservation(signature:[0.2]),nil,AnalysisObservation(signature:[0.8]),AnalysisObservation(signature:[0.8])])
        var engine = RuleEvaluationEngine(); var events: [WatchEvent] = []
        for _ in 0..<4 {
            if let observation = provider.next() { if let event = engine.evaluate(observation,watch:watch) {events.append(event)} }
            else { engine.unavailable() }
        }
        XCTAssertTrue(events.isEmpty)
    }
    func testStatusPersistsWithoutTurningPauseIntoActive() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        let repo = WatchRepository(directory:folder)
        var data = StoredData()
        for status in [WatchStatus.paused,.triggered,.waitingForSource,.permissionRequired,.active,.error] {
            var w = WatchConfiguration(name:status.rawValue,source:CaptureSource(kind:.display,id:1,name:"Mock",region:Region(width:100,height:100)))
            w.status = status; data.watches.append(w)
        }
        try repo.save(data)
        XCTAssertEqual(try repo.load().watches.map(\.status),data.watches.map(\.status))
    }
}
#if !PACKAGE_CORE
import CoreMedia
import CoreVideo
import ScreenCaptureKit
final class NativeCaptureLifecycleTests: XCTestCase {
    final class MockCaptureProvider: CaptureProvider {
        var stopped = false
        func frame() throws -> CapturedFrame {
            if stopped { throw CaptureFailure(message:"Stopped") }
            let context = CGContext(data:nil,width:16,height:16,bitsPerComponent:8,bytesPerRow:16,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
            context.setFillColor(gray:0.5,alpha:1); context.fill(CGRect(x:0,y:0,width:16,height:16))
            return CapturedFrame(image:context.makeImage()!,sequence:1)
        }
        func stop() async { stopped = true }
    }
    func sample(status: SCFrameStatus? = .complete, grey: UInt8 = 128) throws -> CMSampleBuffer {
        var pixel: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil,32,32,kCVPixelFormatType_32BGRA,[kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary,&pixel),kCVReturnSuccess)
        let buffer = try XCTUnwrap(pixel)
        CVPixelBufferLockBaseAddress(buffer,[])
        let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to:UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<32 { for x in 0..<32 { let offset = y*stride+x*4; bytes[offset] = grey; bytes[offset+1] = grey; bytes[offset+2] = grey; bytes[offset+3] = 255 } }
        CVPixelBufferUnlockBaseAddress(buffer,[])
        var format: CMVideoFormatDescription?
        XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator:nil,imageBuffer:buffer,formatDescriptionOut:&format),noErr)
        var timing = CMSampleTimingInfo(duration:CMTime(value:2,timescale:1),presentationTimeStamp:.zero,decodeTimeStamp:.invalid)
        var sample: CMSampleBuffer?
        XCTAssertEqual(CMSampleBufferCreateReadyWithImageBuffer(allocator:nil,imageBuffer:buffer,formatDescription:try XCTUnwrap(format),sampleTiming:&timing,sampleBufferOut:&sample),noErr)
        let result = try XCTUnwrap(sample)
        if let status {
            let attachments = CMSampleBufferGetSampleAttachmentsArray(result,createIfNecessary:true)! as! [NSMutableDictionary]
            attachments[0][SCStreamFrameInfo.status.rawValue] = status.rawValue
        }
        return result
    }
    func testUserStopInvalidatesFrameAndRequiresExplicitResume() throws {
        let session = CaptureSession(); session.accept(try sample())
        session.recordStop(NSError(domain:SCStreamErrorDomain,code:SCStreamError.Code.userStopped.rawValue))
        XCTAssertThrowsError(try session.frame()) { error in
            XCTAssertEqual((error as? CaptureFailure)?.kind,.userStopped)
        }
    }
    func testPermissionDeclineIsDistinguishedFromSourceLoss() throws {
        let session = CaptureSession(); session.accept(try sample())
        session.recordStop(NSError(domain:SCStreamErrorDomain,code:SCStreamError.Code.userDeclined.rawValue))
        XCTAssertThrowsError(try session.frame()) { error in
            XCTAssertEqual((error as? CaptureFailure)?.kind,.permissionRequired)
        }
    }
    func testBlankInvalidatesPreviouslyCompleteFrame() throws {
        let session = CaptureSession()
        session.accept(try sample()); XCTAssertNoThrow(try session.frame())
        session.accept(try sample(status:.blank)); XCTAssertThrowsError(try session.frame())
    }
    func testMissingMetadataInvalidatesPreviouslyCompleteFrame() throws {
        let session = CaptureSession()
        session.accept(try sample()); XCTAssertNoThrow(try session.frame())
        session.accept(try sample(status:nil)); XCTAssertThrowsError(try session.frame())
    }
    func testBackpressureRetainsOnlyLatestCompleteFrame() throws {
        let session = CaptureSession()
        session.accept(try sample(grey:40)); session.accept(try sample(grey:200))
        let frame = try session.frame()
        XCTAssertEqual(frame.sequence,2); XCTAssertEqual(session.dropped,1)
        XCTAssertGreaterThan(ImageComparisonService.signature(frame.image)[0],0.7)
    }
    func testStopReleasesPreviouslyRetainedFrame() async throws {
        let session = CaptureSession(); session.accept(try sample())
        XCTAssertNoThrow(try session.frame()); await session.stop(); XCTAssertThrowsError(try session.frame())
        session.accept(try sample()); XCTAssertThrowsError(try session.frame())
    }
    func testProviderStopsWithoutPermissions() async throws {
        let provider = MockCaptureProvider(); XCTAssertNoThrow(try provider.frame()); await provider.stop(); XCTAssertThrowsError(try provider.frame())
    }
    func testStoppedRealSessionHasNoRetainedFrame() async {
        let session = CaptureSession(); await session.stop(); XCTAssertThrowsError(try session.frame())
    }
}
#endif
