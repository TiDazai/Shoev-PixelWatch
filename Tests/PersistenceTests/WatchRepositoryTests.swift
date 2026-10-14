import XCTest
import Foundation
#if PACKAGE_CORE
@testable import PixelWatchCore
#else
@testable import PixelWatch
#endif

final class WatchRepositoryTests: XCTestCase {
    var folder: URL!
    override func setUp() { folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    override func tearDown() { try? FileManager.default.removeItem(at:folder) }
    func testRoundTripRulesAndEvents() throws {
        let repo = WatchRepository(directory:folder)
        var data = StoredData()
        var rule = WatchRule(); rule.mode = .textDisappears; rule.text = "Обработка"; rule.oneShot = false
        let w = WatchConfiguration(name:"Status",source:CaptureSource(kind:.window,id:42,name:"Browser",region:Region(width:400,height:200),bundleID:"test.browser"),rule:rule)
        data.watches = [w]; data.events = [WatchEvent(watchID:w.id,date:Date(),reason:"Changed",previous:"Pending",current:"Approved")]
        data.settings.sound = false
        try repo.save(data)
        let loaded = try repo.load()
        XCTAssertEqual(loaded.watches[0].id,w.id); XCTAssertEqual(loaded.watches[0].rule,rule)
        XCTAssertEqual(loaded.events[0].current,"Approved"); XCTAssertFalse(loaded.settings.sound)
        let mode = try FileManager.default.attributesOfItem(atPath:folder.appendingPathComponent("pixelwatch.json").path)[.posixPermissions] as? Int
        XCTAssertEqual(mode,0o600)
    }
    func testEmptyRepository() throws { XCTAssertTrue(try WatchRepository(directory:folder).load().watches.isEmpty) }
    func testCorruptionIsReportedAndPreserved() throws {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let file = folder.appendingPathComponent("pixelwatch.json"); try Data("broken".utf8).write(to:file)
        XCTAssertThrowsError(try WatchRepository(directory:folder).load()); XCTAssertEqual(try Data(contentsOf:file),Data("broken".utf8))
    }
    func testSavingCannotOverwriteCorruptData() throws {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let file = folder.appendingPathComponent("pixelwatch.json")
        try Data("broken".utf8).write(to:file)
        XCTAssertThrowsError(try WatchRepository(directory:folder).save(StoredData()))
        XCTAssertEqual(try Data(contentsOf:file),Data("broken".utf8))
    }
    func testDeleteAll() throws {
        let repo = WatchRepository(directory:folder); try repo.save(StoredData()); try repo.deleteAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath:folder.path))
    }
    func testValidationAndCoordinates() {
        var rule = WatchRule(); rule.interval = -1; rule.confirmations = 0; rule.sensitivity = 2
        let valid = rule.validated(); XCTAssertEqual(valid.interval,0.5); XCTAssertEqual(valid.confirmations,2); XCTAssertEqual(valid.sensitivity,1)
        XCTAssertFalse(Region(x:-20,width:100,height:100).isValid)
        XCTAssertFalse(Region(width:.nan,height:100).isValid)
        XCTAssertTrue(Region(x:0,y:0,width:100,height:100).isValid)
    }
}
