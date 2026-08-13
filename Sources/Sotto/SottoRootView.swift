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
    @State private var selection: SottoDestination = .home

    var body: some View {
        HStack(spacing: 0) {
            SottoSidebar(model: model, selection: $selection)
                .frame(width: 224)

            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.canvas)
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
            SottoSidebarHeader()

            Rectangle()
                .fill(theme.colors.border)
                .frame(height: 1)
                .padding(.horizontal, theme.spacing.md)
                .padding(.bottom, theme.spacing.lg)

            SottoSidebarSection(title: "ESPACIO DE TRABAJO", destinations: workspace, selection: $selection)

            SottoSidebarSection(title: "CONFIGURACIÓN", destinations: configuration, selection: $selection)
                .padding(.top, theme.spacing.lg)

            Spacer(minLength: theme.spacing.lg)
            SottoSidebarFooter(model: model)
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
                .font(theme.typography.micro)
                .tracking(0.9)
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
            HStack(spacing: 9) {
                SottoIcon(destination.systemImage, size: 13)
                    .foregroundStyle(isSelected ? theme.colors.foreground : theme.colors.mutedForeground)

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

private struct SottoSidebarHeader: View {
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            SottoIcon("waveform", size: 15, weight: .medium)
                .foregroundStyle(theme.colors.accentInk)
                .frame(width: 32, height: 32)
                .background(theme.colors.accentTint)
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous)
                        .strokeBorder(theme.colors.accent.opacity(0.28))
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Sotto")
                    .font(theme.typography.sectionTitle)
                    .tracking(theme.typography.tracking)
                Text("LOCAL VOICE")
                    .font(theme.typography.micro)
                    .tracking(0.8)
                    .foregroundStyle(theme.colors.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.spacing.sm)
        .padding(.top, theme.spacing.xl)
        .padding(.bottom, theme.spacing.lg)
    }
}

private struct SottoSidebarFooter: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            SottoIcon("lock", size: 12)
                .foregroundStyle(theme.colors.mutedForeground)
            SottoBadge(
                model.modelState.isReady ? "100 % local" : model.modelState.title,
                tone: model.modelState.tone
            )
            Spacer()
        }
        .padding(theme.spacing.sm)
        .background(theme.colors.mutedSurface)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous)
                .strokeBorder(theme.colors.border)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))
    }
}
