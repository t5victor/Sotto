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
        case .models: "Motor de voz"
        case .vocabulary: "Vocabulario"
        case .shortcuts: "Atajos"
        case .appearance: "Apariencia"
        case .privacy: "Privacidad"
        }
    }

}

struct SottoRootView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme
    @State private var selection: SottoDestination = .home

    var body: some View {
        HStack(spacing: 0) {
            SottoSidebar(model: model, selection: $selection)
                .frame(width: 224)

            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.surface)
        }
        .background(theme.colors.canvas)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPermissions()
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection {
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

private struct SottoSidebar: View {
    @ObservedObject var model: SottoAppModel
    @Binding var selection: SottoDestination
    @Environment(\.sottoTheme) private var theme

    private let workspace: [SottoDestination] = [.home, .history]
    private let configuration: [SottoDestination] = [
        .models,
        .vocabulary,
        .shortcuts,
        .appearance,
        .privacy,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SottoSidebarSection(title: "Espacio de trabajo", destinations: workspace, selection: $selection)
                .padding(.top, theme.spacing.xl)

            SottoSidebarSection(title: "Configuración", destinations: configuration, selection: $selection)
                .padding(.top, theme.spacing.lg)

            Spacer(minLength: theme.spacing.lg)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.bottom, theme.spacing.md)
        .background(theme.colors.canvas)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.colors.border)
                .frame(width: 1)
        }
    }
}

private struct SottoSidebarSection: View {
    let title: String
    let destinations: [SottoDestination]
    @Binding var selection: SottoDestination
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(theme.typography.caption)
                .tracking(0.1)
                .foregroundStyle(theme.colors.subtleForeground)
                .padding(.horizontal, theme.spacing.sm)
                .padding(.bottom, 5)

            ForEach(destinations) { destination in
                SottoSidebarRow(
                    destination: destination,
                    isSelected: selection == destination
                ) {
                    selection = destination
                }
            }
        }
    }
}

private struct SottoSidebarRow: View {
    let destination: SottoDestination
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(destination.title)
                    .font(theme.typography.label)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(isSelected ? theme.colors.foreground : theme.colors.mutedForeground)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.sm)
            .frame(height: 29)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: theme.motion.regular), value: isSelected)
        .animation(.easeOut(duration: theme.motion.fast), value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: Color {
        if isSelected { return theme.colors.hoverStrong }
        if isHovered { return theme.colors.hover }
        return .clear
    }
}
