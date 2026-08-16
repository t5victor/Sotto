import Foundation
import NaturalLanguage

/// A language hypothesis produced from a short transcript sample.
public struct SottoLanguageDetection: Equatable, Sendable {
    public let language: SottoLanguage
    public let confidence: Double

    public init(language: SottoLanguage, confidence: Double) {
        self.language = language
        self.confidence = confidence
    }
}

/// Detects the language of transcript text without allowing short or mixed
/// samples to make a hard decision.
public struct SottoLanguageDetector: Sendable {
    private static let minimumPrefixWords = 4
    private static let minimumMismatchWords = 10
    private static let minimumMixedSegmentWords = 6
    private static let minimumPrefixConfidence = 0.55
    private static let minimumMismatchConfidence = 0.80
    private static let minimumMixedSegmentConfidence = 0.90
    private static let minimumMismatchMargin = 0.35

    public init() {}

    /// Returns a language hypothesis suitable for locking the language of a
    /// recording session. Very short text is deliberately ignored.
    public func detect(_ text: String) -> SottoLanguageDetection? {
        detect(
            text,
            minimumWordCount: Self.minimumPrefixWords,
            minimumConfidence: Self.minimumPrefixConfidence
        )
    }

    /// Returns a hypothesis only when the final transcript is clearly in a
    /// different language than the configured one.
    public func clearlyMismatchedLanguage(
        in text: String,
        expected: SottoLanguage
    ) -> SottoLanguageDetection? {
        guard expected != .automatic else { return nil }

        guard let detection = detect(
            text,
            minimumWordCount: Self.minimumMismatchWords,
            minimumConfidence: Self.minimumMismatchConfidence
        ), detection.language != expected else {
            return nil
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let expectedConfidence = recognizer.languageHypotheses(withMaximum: 2)[
            NLLanguage(rawValue: expected.rawValue)
        ] ?? 0

        guard detection.confidence - expectedConfidence >= Self.minimumMismatchMargin else {
            return nil
        }
        return detection
    }

    /// Detects either a dominant mismatch or a clearly foreign sentence inside
    /// an otherwise expected-language transcript. Short words and names are
    /// intentionally ignored because they are common in normal speech.
    public func languageWarning(
        in text: String,
        expected: SottoLanguage
    ) -> SottoLanguageDetection? {
        guard expected != .automatic else { return nil }
        if let mismatch = clearlyMismatchedLanguage(in: text, expected: expected) {
            return mismatch
        }

        let segments = text.components(separatedBy: CharacterSet(charactersIn: ".!?;\n"))
        for segment in segments {
            guard let detection = detect(
                segment,
                minimumWordCount: Self.minimumMixedSegmentWords,
                minimumConfidence: Self.minimumMixedSegmentConfidence
            ), detection.language != expected else {
                continue
            }

            let recognizer = NLLanguageRecognizer()
            recognizer.processString(segment)
            let expectedConfidence = recognizer.languageHypotheses(withMaximum: 2)[
                NLLanguage(rawValue: expected.rawValue)
            ] ?? 0
            guard detection.confidence - expectedConfidence >= Self.minimumMismatchMargin else {
                continue
            }
            return detection
        }
        return nil
    }

    private func detect(
        _ text: String,
        minimumWordCount: Int,
        minimumConfidence: Double
    ) -> SottoLanguageDetection? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.wordCount >= minimumWordCount else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(normalized)
        guard let dominantLanguage = recognizer.dominantLanguage,
              let language = SottoLanguage(rawValue: dominantLanguage.rawValue),
              language != .automatic
        else {
            return nil
        }

        let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominantLanguage] ?? 0
        guard confidence >= minimumConfidence else { return nil }
        return SottoLanguageDetection(language: language, confidence: confidence)
    }
}

private extension String {
    var wordCount: Int {
        split(whereSeparator: { $0.isWhitespace })
            .filter { word in
                word.contains { character in character.isLetter }
            }
            .count
    }
}
