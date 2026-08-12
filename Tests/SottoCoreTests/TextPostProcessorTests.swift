import XCTest
@testable import SottoCore

final class TextPostProcessorTests: XCTestCase {
    private let processor = TextPostProcessor()

    func testAppliesLongestVocabularyEntryFirstAndPreservesReplacementSymbols() {
        let vocabulary = [
            VocabularyEntry(spokenForm: "expo flamenco", replacement: "Expoflamenco"),
            VocabularyEntry(spokenForm: "core business platform", replacement: "Core $ Platform"),
        ]

        let result = processor.process(
            "expo flamenco trabaja con core business platform",
            preferences: .default,
            vocabulary: vocabulary
        )

        XCTAssertEqual(result, "Expoflamenco trabaja con Core $ Platform")
    }

    func testRemovesOnlyUnambiguousHesitationSounds() {
        let result = processor.process(
            "eh, bueno esto es, mmm, una prueba",
            preferences: .default,
            vocabulary: []
        )

        XCTAssertEqual(result, "Bueno esto es, una prueba")
    }

    func testNormalizesWhitespacePunctuationAndInitialCapitalization() {
        let result = processor.process(
            "  hola   ,   esto\n funciona  ",
            preferences: .default,
            vocabulary: []
        )

        XCTAssertEqual(result, "Hola, esto funciona")
    }

    func testCanLeaveRawTextUnchangedApartFromOuterWhitespace() {
        var preferences = SottoPreferences.default
        preferences.removeFillers = false
        preferences.normalizeText = false

        let result = processor.process(
            "  eh   texto  ",
            preferences: preferences,
            vocabulary: []
        )

        XCTAssertEqual(result, "eh   texto")
    }

    func testDefaultVocabularyCorrectsTheProductName() {
        let result = processor.process(
            "esta es una prueba de Soto",
            preferences: .default,
            vocabulary: [.sotto]
        )

        XCTAssertEqual(result, "Esta es una prueba de Sotto")
    }
}
