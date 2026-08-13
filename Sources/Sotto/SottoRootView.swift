import SottoCore
import SottoDesignSystem
import SwiftUI

enum SottoDestination: Hashable, Identifiable {
    case home
    case history
    case models
    case vocabulary
    case shortcuts
    case appearance
    case privacy
    case project(UUID)

    var id: String {
        switch self {
        case .home: "home"
        case .history: "history"
        case .models: "models"
        case .vocabulary: "vocabulary"
        case .shortcuts: "shortcuts"
        case .appearance: "appearance"
        case .privacy: "privacy"
        case .project(let id): "project-\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .home: "Inicio"
        case .history: "Historial"
        case .models: "Motor de voz"
        case .vocabulary: "Vocabulario"
        case .shortcuts: "Atajos"
        case .appearance: "Apariencia"
        case .privacy: "Privacidad"
        case .project: "Proyecto"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .history: "clock"
        case .models: "waveform"
        case .vocabulary: "character.book.closed"
        case .shortcuts: "command"
        case .appearance: "circle.lefthalf.filled"
        case .privacy: "lock"
        case .project: "folder"
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
                .frame(width: 320)

            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.surface)
        }
        .background(theme.colors.canvas)
        .onChange(of: model.projects) { _, projects in
            guard case .project(let projectID) = selection,
                  !projects.contains(where: { $0.id == projectID })
            else { return }
            selection = .history
        }
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
        case .project(let projectID):
            if let project = model.projects.first(where: { $0.id == projectID }) {
                SottoProjectView(model: model, project: project)
            } else {
                SottoHistoryView(model: model)
            }
        }
    }
}

private struct SottoSidebar: View {
    @ObservedObject var model: SottoAppModel
    @Binding var selection: SottoDestination
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isCreatingProject = false
    @State private var isShowingSearch = false
    @State private var expandedProjects: Set<UUID> = []
    @State private var projectDraftName = ""
    @State private var isRecentsExpanded = false

    private let workspace: [SottoDestination] = [.home, .history]
    private let configuration: [SottoDestination] = [
        .models,
        .vocabulary,
        .shortcuts,
        .appearance,
        .privacy,
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sidebarHeader

                SottoSidebarAction(title: "Nueva transcripción", systemImage: "square.and.pencil") {
                    selection = .home
                    model.toggleDictation()
                }
                .padding(.top, theme.spacing.lg)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(workspace) { destination in
                        SottoSidebarRow(
                            destination: destination,
                            isSelected: selection == destination
                        ) {
                            selection = destination
                        }
                    }
                }

                let pinnedRecords = model.history.filter { $0.isPinned }
                if !pinnedRecords.isEmpty {
                    SottoSidebarSection(title: "Ancladas") {
                        ForEach(pinnedRecords.prefix(4)) { record in
                            SottoRecentRow(record: record) {
                                selection = record.projectID.map(SottoDestination.project) ?? .history
                            }
                        }
                    }
                    .padding(.top, theme.spacing.lg)
                }

                projectsSection

                recentsSection
                    .padding(.top, theme.spacing.lg)

                Spacer(minLength: theme.spacing.xxl)
            }
            .padding(.top, theme.spacing.lg)
            .padding(.bottom, theme.spacing.md)
        }
        .padding(.horizontal, theme.spacing.lg)
        .background {
            LinearGradient(
                colors: [
                    theme.colors.canvas,
                    theme.colors.canvas,
                    theme.colors.accentTint.opacity(0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.colors.border)
                .frame(width: 1)
        }
        .sheet(isPresented: $isShowingSearch) {
            SottoHistorySearchView(model: model, selection: $selection)
                .sottoTheme(.standard)
        }
        .alert("Nuevo proyecto", isPresented: $isCreatingProject) {
            TextField("Nombre del proyecto", text: $projectDraftName)
            Button("Crear") {
                if let project = model.createProject(name: projectDraftName) {
                    expandedProjects.insert(project.id)
                    selection = .project(project.id)
                }
                projectDraftName = ""
            }
            .disabled(projectDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancelar", role: .cancel) {
                projectDraftName = ""
            }
        } message: {
            Text("Agrupa tus transcripciones para encontrarlas cuando las necesites.")
        }
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.regular),
            value: model.projects
        )
    }

    private var sidebarHeader: some View {
        HStack(spacing: theme.spacing.xs) {
            Text("Sotto")
                .font(theme.typography.sidebarTitle)
                .foregroundStyle(theme.colors.foreground)

            SottoIcon("chevron.down", size: 11, weight: .semibold)
                .foregroundStyle(theme.colors.mutedForeground)

            Spacer(minLength: theme.spacing.sm)

            SottoSidebarIconButton(systemImage: "magnifyingglass", help: "Buscar") {
                isShowingSearch = true
            }

            Menu {
                ForEach(configuration) { destination in
                    Button(destination.title) {
                        selection = destination
                    }
                }
            } label: {
                SottoIcon("slider.horizontal.3", size: 16, weight: .regular)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(SottoSidebarButtonStyle())
            .help("Configuración")
            .accessibilityLabel("Configuración")
        }
        .frame(height: 32)
        .padding(.horizontal, theme.spacing.xs)
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                withAnimation(
                    reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast)
                ) {
                    isRecentsExpanded.toggle()
                }
            } label: {
                HStack(spacing: theme.spacing.xs) {
                    Text("Recientes")
                        .font(theme.typography.sidebarSection)
                        .foregroundStyle(theme.colors.subtleForeground)

                    SottoIcon(
                        isRecentsExpanded ? "chevron.down" : "chevron.right",
                        size: 11,
                        weight: .semibold
                    )
                    .foregroundStyle(theme.colors.subtleForeground)

                    Spacer(minLength: theme.spacing.sm)

                    if !model.history.isEmpty {
                        Circle()
                            .fill(theme.colors.accent)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.horizontal, theme.spacing.sm)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(SottoSidebarButtonStyle())

            if isRecentsExpanded {
                ForEach(model.history.prefix(4)) { record in
                    SottoRecentRow(record: record) {
                        selection = record.projectID.map(SottoDestination.project) ?? .history
                    }
                }
            }
        }
    }

    private var projectsSection: some View {
        SottoSidebarSection(title: "Proyectos", actionTitle: "Nuevo proyecto", action: {
            isCreatingProject = true
        }) {
            ForEach(model.projects) { project in
                SottoProjectRow(
                    project: project,
                    isSelected: selection == .project(project.id),
                    isExpanded: expandedProjects.contains(project.id),
                    transcripts: model.history.filter { $0.projectID == project.id },
                    onSelect: {
                        selection = .project(project.id)
                    },
                    onToggleExpanded: {
                        toggleProject(project.id)
                    }
                )
            }

            if model.projects.isEmpty {
                Button {
                    isCreatingProject = true
                } label: {
                    HStack(spacing: theme.spacing.sm) {
                        SottoIcon("plus", size: 12, weight: .medium)
                        Text("Añade tu primer proyecto")
                    }
                    .font(theme.typography.sidebarMeta)
                    .foregroundStyle(theme.colors.subtleForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, theme.spacing.sm)
                    .frame(height: 32)
                }
                .buttonStyle(SottoSidebarButtonStyle())
            }
        }
        .padding(.top, theme.spacing.lg)
    }

    private func toggleProject(_ id: UUID) {
        if expandedProjects.contains(id) {
            expandedProjects.remove(id)
        } else {
            expandedProjects.insert(id)
        }
    }
}

private struct SottoSidebarSection: View {
    let title: String
    var actionTitle: String?
    let content: AnyView
    @Environment(\.sottoTheme) private var theme

    init<Content: View>(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.content = AnyView(content())
        self.action = action
    }

    private let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(theme.typography.sidebarSection)
                    .foregroundStyle(theme.colors.subtleForeground)

                Spacer(minLength: theme.spacing.sm)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(theme.typography.sidebarSectionAction)
                        .foregroundStyle(theme.colors.subtleForeground)
                        .buttonStyle(SottoSidebarButtonStyle())
                        .help(actionTitle)
                }
            }
            .padding(.horizontal, theme.spacing.sm)
            .padding(.bottom, 5)

            content
        }
    }
}

private struct SottoSidebarButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sottoTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(
                reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
                value: configuration.isPressed
            )
    }
}

private struct SottoSidebarIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @Environment(\.sottoTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            SottoIcon(systemImage, size: 16, weight: .regular)
                .foregroundStyle(isHovered ? theme.colors.foreground : theme.colors.mutedForeground)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(SottoSidebarButtonStyle())
        .onHover { isHovered = $0 }
        .animation(
            .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
            value: isHovered
        )
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct SottoSidebarAction: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @Environment(\.sottoTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.md) {
                SottoIcon(systemImage, size: 16, weight: .regular)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .frame(width: 20)

                Text(title)
                    .font(theme.typography.sidebarAction)
                    .foregroundStyle(theme.colors.foreground)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.sm)
            .frame(height: 34)
            .background(isHovered ? theme.colors.hover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
        }
        .buttonStyle(SottoSidebarButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast), value: isHovered)
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
            HStack(spacing: theme.spacing.md) {
                SottoIcon(destination.systemImage, size: 16, weight: .regular)
                    .foregroundStyle(isSelected ? theme.colors.foreground : theme.colors.mutedForeground)
                    .frame(width: 20)

                Text(destination.title)
                    .font(theme.typography.sidebarItem)
                    .foregroundStyle(isSelected ? theme.colors.foreground : theme.colors.foreground.opacity(0.78))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.sm)
            .frame(height: 34)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(SottoSidebarButtonStyle())
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.regular),
            value: isSelected
        )
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
            value: isHovered
        )
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: Color {
        if isSelected { return theme.colors.hoverStrong }
        if isHovered { return theme.colors.hover }
        return .clear
    }
}

private struct SottoProjectRow: View {
    let project: SottoProject
    let isSelected: Bool
    let isExpanded: Bool
    let transcripts: [TranscriptionRecord]
    let onSelect: () -> Void
    let onToggleExpanded: () -> Void

    @Environment(\.sottoTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Button(action: onToggleExpanded) {
                    SottoIcon(isExpanded ? "chevron.down" : "chevron.right", size: 10, weight: .semibold)
                        .foregroundStyle(theme.colors.subtleForeground)
                        .frame(width: 18, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SottoSidebarButtonStyle())

                Button(action: onSelect) {
                    HStack(spacing: theme.spacing.md) {
                        SottoIcon(project.icon, size: 16)
                            .foregroundStyle(project.accent.color)
                            .frame(width: 20)

                        Text(project.name)
                            .font(theme.typography.sidebarItem)
                            .foregroundStyle(isSelected ? theme.colors.foreground : theme.colors.foreground.opacity(0.78))
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, theme.spacing.xs)
                    .frame(height: 32)
                    .background(rowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
                }
                .buttonStyle(SottoSidebarButtonStyle())
                .onHover { isHovered = $0 }
                .animation(.timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast), value: isHovered)
            }

            if isExpanded {
                if transcripts.isEmpty {
                    Text("Sin transcripciones")
                        .font(theme.typography.sidebarMeta)
                        .foregroundStyle(theme.colors.foreground.opacity(0.72))
                        .padding(.leading, 44)
                        .padding(.vertical, 5)
                } else {
                    ForEach(transcripts.prefix(5)) { transcript in
                        Button(action: onSelect) {
                            Text(transcript.text)
                                .font(theme.typography.sidebarMeta)
                                .foregroundStyle(theme.colors.foreground.opacity(0.72))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 44)
                                .padding(.trailing, theme.spacing.sm)
                                .frame(height: 26)
                        }
                        .buttonStyle(SottoSidebarButtonStyle())
                    }
                }
            }
        }
        .contextMenu {
            Text("\(transcripts.count) transcripciones")
            Divider()
            Button("Abrir proyecto", action: onSelect)
        }
    }

    private var rowBackground: Color {
        if isSelected { return theme.colors.hoverStrong }
        if isHovered { return theme.colors.hover }
        return .clear
    }
}

private struct SottoRecentRow: View {
    let record: TranscriptionRecord
    let action: () -> Void

    @Environment(\.sottoTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.md) {
                SottoIcon(record.isPinned ? "pin.fill" : "clock", size: 14)
                    .foregroundStyle(theme.colors.subtleForeground)
                    .frame(width: 20)

                Text(record.text)
                    .font(theme.typography.sidebarMeta)
                    .foregroundStyle(theme.colors.foreground.opacity(0.72))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.sm)
            .frame(height: 32)
            .background(isHovered ? theme.colors.hover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
        }
        .buttonStyle(SottoSidebarButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast), value: isHovered)
    }
}

private extension SottoAccent {
    var color: Color {
        switch self {
        case .violet: .purple
        case .blue: .blue
        case .coral: .orange
        case .green: .green
        }
    }
}
