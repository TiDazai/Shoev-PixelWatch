import XCTest
#if PACKAGE_CORE
@testable import PixelWatchCore
#else
@testable import PixelWatch
#endif
final class GeometryAndLifecycleTests: XCTestCase {
    func testNegativeMonitorOriginAndFlippedCoordinates() {
        let frame = CGRect(x:-1920,y:-400,width:1920,height:1080)
        let selection = CGRect(x:-1820,y:-300,width:200,height:100)
        let region = RegionGeometry.fromGlobalAppKit(selection,displayFrame:frame)
        XCTAssertEqual(region,Region(x:100,y:880,width:200,height:100))
    }
    func testRetinaDensityAndCaptureCap() {
        let retina = RegionGeometry.pixelSize(width:200,height:100,scale:2)
        XCTAssertEqual(retina.width,400); XCTAssertEqual(retina.height,200)
        let capped = RegionGeometry.pixelSize(width:3000,height:1500,scale:2)
        XCTAssertEqual(capped.width,2048); XCTAssertEqual(capped.height,1024)
    }
    func testInvalidRegionRejected() {
        XCTAssertNil(RegionGeometry.fromLocalAppKit(CGRect(x:0,y:0,width:2,height:2),displaySize:CGSize(width:100,height:100)))
    }
    func testExplicitStateTransitionsRespectUserPause() {
        XCTAssertEqual(WatchStatus.active.transitioning(.pause),.paused)
        XCTAssertEqual(WatchStatus.paused.transitioning(.sourceUnavailable),.paused)
        XCTAssertEqual(WatchStatus.paused.transitioning(.analysisSucceeded),.paused)
        XCTAssertEqual(WatchStatus.active.transitioning(.permissionMissing),.permissionRequired)
        XCTAssertEqual(WatchStatus.permissionRequired.transitioning(.analysisSucceeded),.active)
        XCTAssertEqual(WatchStatus.active.transitioning(.trigger(oneShot:true)),.triggered)
        XCTAssertEqual(WatchStatus.active.transitioning(.trigger(oneShot:false)),.active)
        XCTAssertEqual(WatchStatus.triggered.transitioning(.resume),.active)
    }
}
