import Foundation

public struct TextPostProcessor: Sendable {
    public init() {}

    public func process(
        _ input: String,
        preferences: SottoPreferences,
        vocabulary: [VocabularyEntry]
    ) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        text = applyVocabulary(to: text, entries: vocabulary)

        if preferences.removeFillers {
            text = removeFillers(from: text, language: preferences.language)
        }

        if preferences.normalizeText {
            text = normalize(text)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyVocabulary(to input: String, entries: [VocabularyEntry]) -> String {
        var output = input
        for entry in entries.sorted(by: { $0.spokenForm.count > $1.spokenForm.count }) {
            let spoken = entry.spokenForm.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !spoken.isEmpty else { continue }
            let escaped = NSRegularExpression.escapedPattern(for: spoken)
            let pattern = "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: entry.replacement)
            )
        }
        return output
    }

    /// Deliberately conservative: words such as "bueno", "este" or "like"
    /// can carry meaning, so v1 only strips unambiguous hesitation sounds.
    private func removeFillers(from input: String, language: SottoLanguage) -> String {
        _ = language
        guard let regex = try? NSRegularExpression(
            pattern: "(?iu)(?<![\\p{L}\\p{N}])(?:e+h+|e+m+|m{2,}|u+h+|u+m+)(?![\\p{L}\\p{N}])[, ]*"
        ) else { return input }

        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "")
    }

    private func normalize(_ input: String) -> String {
        var output = input
        output = output.replacingOccurrences(
            of: "[\\t\\n\\r ]+",
            with: " ",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "\\s+([,.;:!?])",
            with: "$1",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "([¿¡])\\s+",
            with: "$1",
            options: .regularExpression
        )

        guard let firstLetter = output.firstIndex(where: { $0.isLetter }) else { return output }
        let uppercase = String(output[firstLetter]).uppercased()
        output.replaceSubrange(firstLetter...firstLetter, with: uppercase)
        return output
    }
}

