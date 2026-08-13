import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

extension SottoModelState {
    var detail: String {
        switch self {
        case .checking: SottoLocalization.string("state.model.checking")
        case .notInstalled: SottoLocalization.string("state.model.not_installed")
        case .installed: SottoLocalization.string("state.model.installed")
        case .downloading(_, let detail): detail
        case .validating: SottoLocalization.string("state.model.validating")
        case .loading: SottoLocalization.string("state.model.loading")
        case .ready: SottoLocalization.string("state.model.ready")
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
