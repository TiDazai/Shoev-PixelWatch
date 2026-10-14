import XCTest
import Foundation
#if PACKAGE_CORE
@testable import PixelWatchCore
#else
@testable import PixelWatch
#endif

final class RuleEvaluationEngineTests: XCTestCase {
    let epoch = Date(timeIntervalSince1970: 1000)
    func watch(_ mode: WatchMode, oneShot: Bool = true, cooldown: Double = 0) -> WatchConfiguration {
        var rule = WatchRule(); rule.mode = mode; rule.text = "Processing"; rule.oneShot = oneShot; rule.cooldown = cooldown
        return WatchConfiguration(name: "Test", source: CaptureSource(kind: .display, id: 1, name: "Fixture", region: Region(width: 200,height: 100)), rule: rule)
    }
    func sample(_ text: String = "", _ seconds: Double = 0, _ reliable: Bool = true, pixel: Float = 0.3) -> AnalysisObservation {
        AnalysisObservation(signature: Array(repeating: pixel,count: 64), text: text,textReliable: reliable,date:epoch.addingTimeInterval(seconds))
    }
    func testTextAppearsDebouncesAndNormalizes() {
        var e = RuleEvaluationEngine(); let w = watch(.textAppears)
        XCTAssertNil(e.evaluate(sample("processing",0),watch:w))
        XCTAssertNotNil(e.evaluate(sample("  PROCESSING \n",2),watch:w))
    }
    func testPartialAndFullMatch() {
        XCTAssertTrue(TextNormalization.matches("Status:  Completed",target:"completed",full:false))
        XCTAssertFalse(TextNormalization.matches("Status: Completed",target:"completed",full:true))
        XCTAssertTrue(TextNormalization.matches("  ЗАЯВКА  ОДОБРЕНА ",target:"заявка одобрена",full:true))
    }
    func testDebounceResetsAfterOpposite() {
        var e = RuleEvaluationEngine(); let w = watch(.textAppears)
        XCTAssertNil(e.evaluate(sample("Processing",0),watch:w))
        XCTAssertNil(e.evaluate(sample("Completed",2),watch:w))
        XCTAssertNil(e.evaluate(sample("Processing",4),watch:w))
        XCTAssertNotNil(e.evaluate(sample("Processing",6),watch:w))
    }
    func testTextDisappearsRequiresConfirmedPresence() {
        var e = RuleEvaluationEngine(); let w = watch(.textDisappears)
        for t in 0..<4 { XCTAssertNil(e.evaluate(sample("Completed",Double(t)),watch:w)) }
        XCTAssertNil(e.evaluate(sample("Processing",4),watch:w))
        XCTAssertNil(e.evaluate(sample("Processing",6),watch:w))
        XCTAssertNil(e.evaluate(sample("Completed",8),watch:w))
        XCTAssertNotNil(e.evaluate(sample("Completed",10),watch:w))
    }
    func testSinglePresenceIsInsufficient() {
        var e = RuleEvaluationEngine(); let w = watch(.textDisappears)
        _ = e.evaluate(sample("Processing"),watch:w)
        XCTAssertNil(e.evaluate(sample("Completed",2),watch:w)); XCTAssertNil(e.evaluate(sample("Completed",4),watch:w))
    }
    func testBlankOCRIsNotDisappearance() {
        var e = RuleEvaluationEngine(); let w = watch(.textDisappears)
        _ = e.evaluate(sample("Processing"),watch:w); _ = e.evaluate(sample("Processing",2),watch:w)
        for t in 3..<10 { XCTAssertNil(e.evaluate(sample("",Double(t)),watch:w)) }
    }
    func testLowConfidenceBreaksConsecutiveConfirmations() {
        var e = RuleEvaluationEngine(); let w = watch(.textDisappears)
        _ = e.evaluate(sample("Processing"),watch:w); _ = e.evaluate(sample("Processing",2),watch:w)
        XCTAssertNil(e.evaluate(sample("Completed",4),watch:w))
        XCTAssertNil(e.evaluate(sample("Completed",6,false),watch:w))
        XCTAssertNil(e.evaluate(sample("Completed",8),watch:w))
        XCTAssertNotNil(e.evaluate(sample("Completed",10),watch:w))
    }
    func testTextChangesEstablishesStableBaselineAndNewValue() {
        var e = RuleEvaluationEngine(); let w = watch(.textChanges)
        _ = e.evaluate(sample("Pending"),watch:w); _ = e.evaluate(sample("Pending",2),watch:w)
        XCTAssertNil(e.evaluate(sample("Approved",4),watch:w))
        let event = e.evaluate(sample("Approved",6),watch:w)
        XCTAssertEqual(event?.previous,"pending"); XCTAssertEqual(event?.current,"Approved")
    }
    func testUnstableTextDoesNotTrigger() {
        var e = RuleEvaluationEngine(); let w = watch(.textChanges)
        _ = e.evaluate(sample("Pending"),watch:w); _ = e.evaluate(sample("Pending",2),watch:w)
        for t in 3..<20 { XCTAssertNil(e.evaluate(sample(t % 2 == 0 ? "Approved" : "Approvcd",Double(t)),watch:w)) }
    }
    func testOneShotStops() {
        var e = RuleEvaluationEngine(); let w = watch(.textAppears)
        _ = e.evaluate(sample("Processing"),watch:w); XCTAssertNotNil(e.evaluate(sample("Processing",2),watch:w))
        _ = e.evaluate(sample("Completed",4),watch:w); _ = e.evaluate(sample("Completed",6),watch:w)
        _ = e.evaluate(sample("Processing",8),watch:w); XCTAssertNil(e.evaluate(sample("Processing",10),watch:w))
    }
    func testContinuousNeedsOppositeStateAndDoesNotRepeat() {
        var e = RuleEvaluationEngine(); let w = watch(.textAppears,oneShot:false)
        _ = e.evaluate(sample("Processing"),watch:w); XCTAssertNotNil(e.evaluate(sample("Processing",2),watch:w))
        for t in 3..<20 { XCTAssertNil(e.evaluate(sample("Processing",Double(t)),watch:w)) }
        _ = e.evaluate(sample("Completed",20),watch:w); _ = e.evaluate(sample("Completed",22),watch:w)
        XCTAssertNil(e.evaluate(sample("Processing",24),watch:w)); XCTAssertNotNil(e.evaluate(sample("Processing",26),watch:w))
    }
    func testSingleOppositeDoesNotRearm() {
        var e = RuleEvaluationEngine(); let w = watch(.textAppears,oneShot:false)
        _ = e.evaluate(sample("Processing"),watch:w); _ = e.evaluate(sample("Processing",2),watch:w)
        _ = e.evaluate(sample("Completed",4),watch:w)
        for t in 5..<10 { XCTAssertNil(e.evaluate(sample("Processing",Double(t)),watch:w)) }
    }
    func testCooldownDefersNewEvent() {
        var e = RuleEvaluationEngine(); let w = watch(.textAppears,oneShot:false,cooldown:30)
        _ = e.evaluate(sample("Processing"),watch:w); XCTAssertNotNil(e.evaluate(sample("Processing",2),watch:w))
        _ = e.evaluate(sample("Completed",4),watch:w); _ = e.evaluate(sample("Completed",6),watch:w)
        _ = e.evaluate(sample("Processing",8),watch:w); XCTAssertNil(e.evaluate(sample("Processing",10),watch:w))
        XCTAssertNotNil(e.evaluate(sample("Processing",32),watch:w))
    }
    func testUnavailableClearsDebounceAndBaseline() {
        var e = RuleEvaluationEngine(); let w = watch(.visualChange)
        _ = e.evaluate(sample(pixel:0.2),watch:w); _ = e.evaluate(sample("",2,pixel:0.8),watch:w)
        e.unavailable()
        XCTAssertNil(e.evaluate(sample("",4,pixel:0.8),watch:w)); XCTAssertNil(e.evaluate(sample("",6,pixel:0.8),watch:w))
    }
    func testMissingSourceCannotConfirmDisappearance() {
        var e = RuleEvaluationEngine(); let w = watch(.textDisappears)
        _ = e.evaluate(sample("Processing"),watch:w); _ = e.evaluate(sample("Processing",2),watch:w)
        e.unavailable()
        for t in 4..<10 { XCTAssertNil(e.evaluate(sample("Completed",Double(t)),watch:w)) }
    }
    func testVisualChangeDebounce() {
        var e = RuleEvaluationEngine(); let w = watch(.visualChange)
        XCTAssertNil(e.evaluate(sample(pixel:0.2),watch:w))
        XCTAssertNil(e.evaluate(sample("",2,pixel:0.8),watch:w)); XCTAssertNotNil(e.evaluate(sample("",4,pixel:0.8),watch:w))
    }
    func testOriginalVisualBaselineRequiresReturn() {
        var e = RuleEvaluationEngine(); var w = watch(.visualChange,oneShot:false); w.rule.compareOriginal = true
        _ = e.evaluate(sample(pixel:0.2),watch:w); _ = e.evaluate(sample("",2,pixel:0.8),watch:w)
        XCTAssertNotNil(e.evaluate(sample("",4,pixel:0.8),watch:w))
        for t in 5..<10 { XCTAssertNil(e.evaluate(sample("",Double(t),pixel:0.9),watch:w)) }
        _ = e.evaluate(sample("",10,pixel:0.2),watch:w); _ = e.evaluate(sample("",12,pixel:0.2),watch:w)
        _ = e.evaluate(sample("",14,pixel:0.8),watch:w); XCTAssertNotNil(e.evaluate(sample("",16,pixel:0.8),watch:w))
    }
    func testChangeAfterStability() {
        var e = RuleEvaluationEngine(); let w = watch(.changeAfterStability)
        for t in 0...6 { XCTAssertNil(e.evaluate(sample("",Double(t),pixel:0.3),watch:w)) }
        XCTAssertNil(e.evaluate(sample("",8,pixel:0.8),watch:w)); XCTAssertNotNil(e.evaluate(sample("",10,pixel:0.8),watch:w))
    }
    func testAnimationNeverArmsStability() {
        var e = RuleEvaluationEngine(); let w = watch(.changeAfterStability)
        for t in 0..<30 { XCTAssertNil(e.evaluate(sample("",Double(t),pixel:t % 2 == 0 ? 0.2 : 0.8),watch:w)) }
    }
    func testContinuousTextChangesAcceptsFurtherValues() {
        var e = RuleEvaluationEngine(); let w = watch(.textChanges,oneShot:false)
        _ = e.evaluate(sample("Pending"),watch:w); _ = e.evaluate(sample("Pending",2),watch:w)
        _ = e.evaluate(sample("Approved",4),watch:w); XCTAssertNotNil(e.evaluate(sample("Approved",6),watch:w))
        XCTAssertNil(e.evaluate(sample("Approved",8),watch:w))
        _ = e.evaluate(sample("Completed",10),watch:w); XCTAssertNotNil(e.evaluate(sample("Completed",12),watch:w))
    }
}
