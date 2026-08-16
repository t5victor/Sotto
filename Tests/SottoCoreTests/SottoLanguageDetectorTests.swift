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

    func testWarnsAboutClearlyEnglishTranscriptWhenSpanishWasExpected() {
        let mismatch = detector.languageWarning(
            in: "This is a complete sentence spoken in English and it contains enough words to identify the language with confidence.",
            expected: .spanish
        )

        XCTAssertEqual(mismatch?.language, .english)
    }

    func testWarnsAboutAConfidentEnglishSegmentInsideSpanishText() {
        let warning = detector.languageWarning(
            in: "Esta parte está en español y sirve como contexto suficiente. This is a clearly English sentence with enough words to trigger a warning.",
            expected: .spanish
        )

        XCTAssertEqual(warning?.language, .english)
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

    func testTranscriptCanCarryAWarningWithoutChangingItsText() throws {
        let warning = SottoLanguageWarning(expected: .spanish, detected: .english)
        let transcript = SottoTranscript(
            text: "Texto completo con una palabra inglesa",
            confidence: 0.7,
            duration: 24,
            processingTime: 1.2,
            languageWarning: warning
        )

        let data = try JSONEncoder().encode(transcript)
        let decoded = try JSONDecoder().decode(SottoTranscript.self, from: data)

        XCTAssertEqual(decoded.text, transcript.text)
        XCTAssertEqual(decoded.languageWarning, warning)
    }
}
