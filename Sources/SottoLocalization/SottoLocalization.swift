import Foundation

/// Shared localization access for the app and its reusable modules.
///
/// Keeping lookup in one target makes strings emitted by SottoCore and
/// SottoDesignSystem use the same catalog as the main app.
public enum SottoLocalization {
    public static func string(_ key: String, locale: Locale = .current) -> String {
        localizedBundle(for: locale).localizedString(
            forKey: key,
            value: nil,
            table: "Localizable"
        )
    }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: string(key),
            locale: Locale.current,
            arguments: arguments
        )
    }

    public static func count(_ singularKey: String, _ pluralKey: String, _ value: Int) -> String {
        format(value == 1 ? singularKey : pluralKey, Int64(value))
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        let identifiers = [
            locale.identifier,
            locale.identifier.split(whereSeparator: { $0 == "_" || $0 == "-" }).first.map(String.init),
        ].compactMap { $0 }

        for identifier in identifiers {
            guard let path = Bundle.module.path(forResource: identifier, ofType: "lproj"),
                  let bundle = Bundle(path: path)
            else { continue }
            return bundle
        }

        return .module
    }
}
