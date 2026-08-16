import SottoCore
import SottoLocalization
import XCTest

final class LocalizationTests: XCTestCase {
    func testCatalogProvidesEnglishAndSpanishValues() {
        XCTAssertEqual(
            SottoLocalization.string("home.title", locale: Locale(identifier: "es")),
            "Habla. Sotto escribe."
        )
        XCTAssertEqual(
            SottoLocalization.string("home.title", locale: Locale(identifier: "en")),
            "Speak. Sotto writes."
        )
        XCTAssertEqual(
            SottoLocalization.string("home.title", locale: Locale(identifier: "fr_FR")),
            "Parlez. Sotto écrit."
        )
        XCTAssertEqual(
            SottoLocalization.string("home.title", locale: Locale(identifier: "pt_BR")),
            "Fale. Sotto escreve."
        )
    }

    func testCoreDisplayNamesUseTheActiveLocale() {
        XCTAssertEqual(
            SottoLocalization.string("outcome.paste_attempted", locale: Locale(identifier: "en")),
            "Paste requested"
        )
        XCTAssertEqual(
            SottoLocalization.string("outcome.paste_attempted", locale: Locale(identifier: "es")),
            "Pegado solicitado"
        )
        XCTAssertFalse(SottoLanguage.english.displayName.isEmpty)
    }
}
