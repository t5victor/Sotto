import SottoCore
import SottoDesignSystem
import SwiftUI

extension SottoModelState {
    var detail: String {
        switch self {
        case .checking: "Comprobando la instalación…"
        case .notInstalled: "Instala el motor para empezar a dictar."
        case .installed: "El motor está listo para usar."
        case .downloading(_, let detail): detail
        case .validating: "Comprobando los archivos…"
        case .loading: "Cargando el motor…"
        case .ready: "Listo para dictar."
        case .failed(let message): message
        }
    }

}

extension SottoPermissionStatus {
    var designState: SottoPermissionState {
        switch self {
        case .granted: .granted
        case .notDetermined, .denied: .required
        case .restricted: .unavailable
        }
    }
}
