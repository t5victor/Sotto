import XCTest
@testable import SottoCore

final class SottoLanguageDetectorTests: XCTestCase {
    private let detector = SottoLanguageDetector()

    func testDetectsSpanishFromAConfidentSample() {
        let detection = detector.detect(
            "Esta es una frase completamente hablada en español y contiene suficientes palabras para identificar el idioma con claridad."
        )

        XCTAssertEqual(detection?.language, .spanish)
        XCTAssertGreaterThan(detection?.confidence ?? 0, 0.55)
    }

    func testDetectsEnglishFromAConfidentSample() {
        let detection = detector.detect(
            "This is a complete sentence spoken in English and it contains enough words to identify the language with confidence."
        )

        XCTAssertEqual(detection?.language, .english)
        XCTAssertGreaterThan(detection?.confidence ?? 0, 0.55)
    }

    func testRejectsClearlyEnglishTranscriptWhenSpanishWasExpected() {
        let mismatch = detector.clearlyMismatchedLanguage(
            in: "This is a complete sentence spoken in English and it contains enough words to identify the language with confidence.",
            expected: .spanish
        )

        XCTAssertEqual(mismatch?.language, .english)
    }

    func testDoesNotMakeAHardDecisionForShortText() {
        XCTAssertNil(detector.detect("Hola mundo"))
        XCTAssertNil(
            detector.clearlyMismatchedLanguage(
                in: "Hello world",
                expected: .spanish
            )
        )
    }
}
