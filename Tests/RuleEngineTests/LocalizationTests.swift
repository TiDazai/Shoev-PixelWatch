import XCTest
#if PACKAGE_CORE
@testable import PixelWatchCore
#else
@testable import PixelWatch
#endif
final class LocalizationTests: XCTestCase {
    func testRussianResourcesAndEnglishFallback() {
        XCTAssertEqual(L10n.text("New Watch",language:"ru"),"Новое наблюдение")
        XCTAssertEqual(L10n.text("New Watch",language:"en"),"New Watch")
        XCTAssertEqual(L10n.text("A user-provided name",language:"ru"),"A user-provided name")
        XCTAssertGreaterThan(L10n.translatedKeys.count,160)
    }
    func testAllModesAndStatusesHaveRussianTranslations() {
        for mode in WatchMode.allCases { XCTAssertNotEqual(L10n.text(mode.title,language:"ru"),mode.title) }
        for status in [WatchStatus.active,.paused,.triggered,.waitingForSource,.permissionRequired,.error] {
            XCTAssertNotEqual(L10n.text(status.rawValue,language:"ru"),status.rawValue)
        }
    }
    func testFormattingPreservesTextIncludingPercentCharacters() {
        XCTAssertEqual(L10n.format("Active watches: %ld",3,language:"ru"),"Активных наблюдений: 3")
        XCTAssertEqual(L10n.format("\"%@\" appeared in your watched area.","Completed 100%",language:"ru"),"Текст «Completed 100%» появился в наблюдаемой области.")
    }
    func testEventsCanChangeLanguageWithoutChangingRecognizedText() {
        let event = WatchEvent(watchID:UUID(),date:Date(),reason:"Stored English fallback",previous:"Pending",current:"Approved",mode:.textChanges)
        XCTAssertEqual(EventPresentation.reason(event,language:"ru"),"Текст изменился с «Pending» на «Approved».")
        XCTAssertEqual(EventPresentation.reason(event,language:"en"),"Text changed from \"Pending\" to \"Approved\".")
        XCTAssertEqual(EventPresentation.previous(event,language:"ru"),"Pending")
        XCTAssertEqual(EventPresentation.current(event,language:"ru"),"Approved")
    }
    func testExistingEventsDecodeWithoutNewPresentationMetadata() throws {
        let id = UUID().uuidString
        let data = Data("{\"id\":\"\(id)\",\"watchID\":\"\(id)\",\"date\":0,\"reason\":\"The selected area has changed.\"}".utf8)
        let event = try JSONDecoder().decode(WatchEvent.self,from:data)
        XCTAssertNil(event.mode)
        XCTAssertEqual(EventPresentation.reason(event,language:"ru"),"Выбранная область изменилась.")
    }
    func testLegacyTextEventsRemainLocalized() {
        let event = WatchEvent(watchID:UUID(),date:Date(),reason:"\"Completed 100%\" appeared in your watched area.")
        XCTAssertEqual(EventPresentation.reason(event,language:"ru"),"Текст «Completed 100%» появился в наблюдаемой области.")
    }
    func testRussianIsDefaultAndEnglishPreferencePersists() throws {
        XCTAssertEqual(AppSettings().language,"ru")
        var settings = AppSettings(); settings.language = "en"
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self,from:JSONEncoder().encode(settings)).language,"en")
    }
}

#if !PACKAGE_CORE
final class CompiledLocalizationCatalogTests: XCTestCase {
    func testCompiledCatalogRetainsRussianAndEnglishAfterIncrementalBuild() throws {
        for language in ["ru","en"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource:language,ofType:"lproj"))
            let bundle = try XCTUnwrap(Bundle(path:path))
            for key in L10n.translatedKeys {
                XCTAssertEqual(bundle.localizedString(forKey:key,value:nil,table:"Localizable"),L10n.text(key,language:language),key)
            }
        }
    }
}
#endif
