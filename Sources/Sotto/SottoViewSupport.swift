import SottoCore
import SottoDesignSystem
import SwiftUI

extension SottoModelState {
    var title: String {
        switch self {
        case .checking: "Comprobando"
        case .notInstalled: "No instalado"
        case .installed: "Instalado"
        case .downloading: "Descargando"
        case .validating: "Validando"
        case .loading: "Cargando"
        case .ready: "Preparado"
        case .failed: "Necesita atención"
        }
    }

    var detail: String {
        switch self {
        case .checking: "Buscando el modelo local…"
        case .notInstalled: "Descarga única desde Hugging Face. Después funciona sin conexión."
        case .installed: "Los archivos del modelo están disponibles en este Mac."
        case .downloading(_, let detail): detail
        case .validating: "Comprobando que todos los artefactos Core ML son válidos."
        case .loading: "Cargando Parakeet en Core ML y el Neural Engine."
        case .ready: "Parakeet está cargado y preparado para dictar."
        case .failed(let message): message
        }
    }

    var tone: SottoBadgeTone {
        switch self {
        case .ready, .installed: .success
        case .downloading, .validating, .loading, .checking: .accent
        case .notInstalled: .warning
        case .failed: .destructive
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
