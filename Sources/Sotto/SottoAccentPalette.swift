import SottoCore
import SottoDesignSystem

extension SottoAccent {
    var themePalette: SottoColorPair {
        switch self {
        case .violet: SottoPalette.violetAccent
        case .blue: SottoPalette.blueAccent
        case .coral: SottoPalette.coralAccent
        case .green: SottoPalette.greenAccent
        }
    }
}
