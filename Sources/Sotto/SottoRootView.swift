import SottoCore
import SottoDesignSystem
import SwiftUI

enum SottoDestination: String, CaseIterable, Identifiable {
    case home
    case history
    case models
    case vocabulary
    case shortcuts
    case appearance
    case privacy

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Inicio"
        case .history: "Historial"
        case .models: "Modelos"
        case .vocabulary: "Vocabulario"
        case .shortcuts: "Atajos"
        case .appearance: "Apariencia"
        case .privacy: "Privacidad"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "waveform"
        case .history: "clock.arrow.circlepath"
        case .models: "cpu"
        case .vocabulary: "text.book.closed"
        case .shortcuts: "command"
        case .appearance: "paintpalette"
        case .privacy: "lock.shield"
        }
    }
}

struct SottoRootView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme
    @State private var selection: SottoDestination? = .home

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SottoSidebarHeader()

                List(SottoDestination.allCases, selection: $selection) { destination in
                    Label(destination.title, systemImage: destination.systemImage)
                        .tag(destination)
                }
                .listStyle(.sidebar)

                SottoSidebarFooter(model: model)
            }
            .background(.ultraThinMaterial)
            .navigationSplitViewColumnWidth(min: 190, ideal: 216, max: 250)
        } detail: {
            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.canvas)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPermissions()
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection ?? .home {
        case .home:
            SottoHomeView(model: model)
        case .history:
            SottoHistoryView(model: model)
        case .models:
            SottoModelsView(model: model)
        case .vocabulary:
            SottoVocabularyView(model: model)
        case .shortcuts:
            SottoShortcutsView(model: model)
        case .appearance:
            SottoAppearanceView(model: model)
        case .privacy:
            SottoPrivacyView(model: model)
        }
    }
}

private struct SottoSidebarHeader: View {
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.colors.accentForeground)
                .frame(width: 30, height: 30)
                .background(theme.colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text("Sotto")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Dictado local")
                    .font(.caption)
                    .foregroundStyle(theme.colors.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.spacing.md)
        .padding(.top, theme.spacing.xl)
        .padding(.bottom, theme.spacing.md)
    }
}

private struct SottoSidebarFooter: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        HStack {
            SottoBadge(
                model.modelState.isReady ? "100 % local" : model.modelState.title,
                systemImage: model.modelState.isReady ? "lock.fill" : "arrow.down.circle",
                tone: model.modelState.tone
            )
            Spacer()
        }
        .padding(theme.spacing.md)
    }
}

