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
        HSplitView {
            SottoSidebar(model: model, selection: $selection)
                .frame(minWidth: 76, idealWidth: 320, maxWidth: 420, maxHeight: .infinity)

            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.surface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @State private var projectDraftIcon = "folder"
    @State private var projectDraftAccent: SottoAccent = .blue
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
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 180

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    sidebarHeader(isCompact: isCompact)

                    SottoSidebarAction(
                        title: "Nueva transcripción",
                        systemImage: "square.and.pencil",
                        isCompact: isCompact
                    ) {
                        selection = .home
                        model.toggleDictation()
                    }
                    .padding(.top, isCompact ? theme.spacing.sm : theme.spacing.lg)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(workspace) { destination in
                            SottoSidebarRow(
                                destination: destination,
                                isSelected: selection == destination,
                                isCompact: isCompact
                            ) {
                                selection = destination
                            }
                        }
                    }

                    let pinnedRecords = model.history.filter { $0.isPinned }
                    if !isCompact, !pinnedRecords.isEmpty {
                        SottoSidebarSection(title: "Ancladas") {
                            ForEach(pinnedRecords.prefix(4)) { record in
                                SottoRecentRow(record: record) {
                                    selection = record.projectID.map(SottoDestination.project) ?? .history
                                }
                            }
                        }
                        .padding(.top, theme.spacing.lg)
                    }

                    projectsSection(isCompact: isCompact)

                    recentsSection(isCompact: isCompact)
                        .padding(.top, isCompact ? theme.spacing.sm : theme.spacing.lg)

                    Spacer(minLength: theme.spacing.xxl)
                }
                .padding(.top, isCompact ? theme.spacing.sm : theme.spacing.lg)
                .padding(.bottom, theme.spacing.md)
            }
            .padding(.horizontal, isCompact ? theme.spacing.xs : theme.spacing.lg)
        }
        .background(theme.colors.canvas)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.colors.border)
                .frame(width: 1)
        }
        .sheet(isPresented: $isShowingSearch) {
            SottoHistorySearchView(model: model, selection: $selection)
                .sottoTheme(.standard)
        }
        .sheet(isPresented: $isCreatingProject, onDismiss: resetProjectDraft) {
            SottoProjectCreationSheet(
                name: $projectDraftName,
                icon: $projectDraftIcon,
                accent: $projectDraftAccent,
                onCancel: {
                    isCreatingProject = false
                },
                onCreate: createProject
            )
            .sottoTheme(.standard)
            .frame(width: 520, height: 360)
            .fixedSize()
            .modifier(SottoFittedSheetSizing())
        }
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.regular),
            value: model.projects
        )
    }

    private func sidebarHeader(isCompact: Bool) -> some View {
        HStack(spacing: theme.spacing.xs) {
            if !isCompact {
                Text("Sotto")
                    .font(theme.typography.sidebarTitle)
                    .foregroundStyle(theme.colors.foreground)
            }

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
            .frame(width: 28, height: 28)
            .help("Configuración")
            .accessibilityLabel("Configuración")
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .padding(.horizontal, isCompact ? 0 : theme.spacing.xs)
    }

    private func recentsSection(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                withAnimation(
                    reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast)
                ) {
                    isRecentsExpanded.toggle()
                }
            } label: {
                HStack(spacing: theme.spacing.xs) {
                    if !isCompact {
                        Text("Recientes")
                            .font(theme.typography.sidebarSection)
                            .foregroundStyle(theme.colors.subtleForeground)
                    }

                    SottoIcon(
                        isRecentsExpanded ? "chevron.down" : "chevron.right",
                        size: isCompact ? 14 : 11,
                        weight: .semibold
                    )
                    .foregroundStyle(theme.colors.subtleForeground)

                    Spacer(minLength: theme.spacing.sm)

                    if !isCompact, !model.history.isEmpty {
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

            if isRecentsExpanded, !isCompact {
                ForEach(model.history.prefix(4)) { record in
                    SottoRecentRow(record: record) {
                        selection = record.projectID.map(SottoDestination.project) ?? .history
                    }
                }
            }
        }
    }

    private func projectsSection(isCompact: Bool) -> some View {
        SottoSidebarSection(
            title: "Proyectos",
            actionTitle: "Nuevo proyecto",
            actionSystemImage: "plus",
            isCompact: isCompact,
            action: beginProjectCreation
        ) {
            ForEach(model.projects) { project in
                SottoProjectRow(
                    project: project,
                    isSelected: selection == .project(project.id),
                    isExpanded: expandedProjects.contains(project.id),
                    transcripts: model.history.filter { $0.projectID == project.id },
                    isCompact: isCompact,
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
                    beginProjectCreation()
                } label: {
                    HStack(spacing: theme.spacing.sm) {
                        SottoIcon("plus", size: isCompact ? 15 : 13, weight: .regular)
                        if !isCompact {
                            Text("Añade tu primer proyecto")
                        }
                    }
                    .font(theme.typography.sidebarItem)
                    .foregroundStyle(theme.colors.foreground.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
                    .padding(.horizontal, isCompact ? 0 : theme.spacing.sm)
                    .frame(height: 30)
                }
                .buttonStyle(SottoSidebarButtonStyle())
            }
        }
        .padding(.top, isCompact ? theme.spacing.sm : theme.spacing.lg)
    }

    private func beginProjectCreation() {
        projectDraftName = ""
        projectDraftIcon = "folder"
        projectDraftAccent = .blue
        isCreatingProject = true
    }

    private func createProject(name: String, icon: String, accent: SottoAccent) {
        if let project = model.createProject(name: name, icon: icon, accent: accent) {
            expandedProjects.insert(project.id)
            selection = .project(project.id)
        }
        isCreatingProject = false
    }

    private func resetProjectDraft() {
        projectDraftName = ""
        projectDraftIcon = "folder"
        projectDraftAccent = .blue
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
    var actionSystemImage: String?
    var isCompact: Bool
    let content: AnyView
    @Environment(\.sottoTheme) private var theme

    init<Content: View>(
        title: String,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        isCompact: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.isCompact = isCompact
        self.content = AnyView(content())
        self.action = action
    }

    private let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                if !isCompact {
                    Text(title)
                        .font(theme.typography.sidebarSection)
                        .foregroundStyle(theme.colors.subtleForeground)
                }

                Spacer(minLength: theme.spacing.sm)

                if let actionTitle, let action {
                    Button(action: action) {
                        if let actionSystemImage {
                            SottoIcon(actionSystemImage, size: isCompact ? 15 : 14, weight: .regular)
                        } else {
                            Text(actionTitle)
                                .font(theme.typography.sidebarItem)
                        }
                    }
                        .foregroundStyle(theme.colors.foreground.opacity(0.72))
                        .buttonStyle(SottoSidebarButtonStyle())
                        .help(actionTitle)
                        .accessibilityLabel(actionTitle)
                }
            }
            .padding(.horizontal, theme.spacing.sm)
            .frame(height: isCompact ? 28 : 30)

            content
        }
    }
}

private struct SottoFittedSheetSizing: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.presentationSizing(.fitted)
        } else {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
            value: isHovered
        )
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct SottoSidebarAction: View {
    let title: String
    let systemImage: String
    let isCompact: Bool
    let action: () -> Void
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.sm) {
                SottoIcon(systemImage, size: isCompact ? 16 : 15, weight: .regular)
                    .foregroundStyle(theme.colors.foreground.opacity(0.72))
                    .frame(width: isCompact ? 28 : 20)

                if !isCompact {
                    Text(title)
                        .font(theme.typography.sidebarItem)
                        .foregroundStyle(theme.colors.foreground.opacity(0.72))

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            .padding(.horizontal, isCompact ? 0 : theme.spacing.sm)
            .frame(height: 30)
            .background(isHovered ? theme.colors.hover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
        }
        .buttonStyle(SottoSidebarButtonStyle())
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
            value: isHovered
        )
        .accessibilityLabel(title)
    }
}

private struct SottoSidebarRow: View {
    let destination: SottoDestination
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void

    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.sm) {
                SottoIcon(destination.systemImage, size: isCompact ? 16 : 15, weight: .regular)
                    .foregroundStyle(theme.colors.foreground.opacity(0.72))
                    .frame(width: isCompact ? 28 : 20)

                if !isCompact {
                    Text(destination.title)
                        .font(theme.typography.sidebarItem)
                        .foregroundStyle(theme.colors.foreground.opacity(0.72))

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            .padding(.horizontal, isCompact ? 0 : theme.spacing.sm)
            .frame(height: 30)
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
        .accessibilityLabel(destination.title)
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
    let isCompact: Bool
    let onSelect: () -> Void
    let onToggleExpanded: () -> Void

    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                if !isCompact {
                    Button(action: onToggleExpanded) {
                        SottoIcon(isExpanded ? "chevron.down" : "chevron.right", size: 10, weight: .semibold)
                            .foregroundStyle(theme.colors.subtleForeground)
                            .frame(width: 18, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SottoSidebarButtonStyle())
                }

                Button(action: onSelect) {
                    HStack(spacing: theme.spacing.md) {
                        SottoIcon(project.icon, size: isCompact ? 16 : 15)
                            .foregroundStyle(project.accent.color)
                            .frame(width: isCompact ? 28 : 20)

                        if !isCompact {
                            Text(project.name)
                                .font(theme.typography.sidebarItem)
                                .foregroundStyle(theme.colors.foreground.opacity(0.72))
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
                    .padding(.horizontal, isCompact ? 0 : theme.spacing.xs)
                    .frame(height: 30)
                    .background(rowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
                }
                .buttonStyle(SottoSidebarButtonStyle())
                .onHover { isHovered = $0 }
                .animation(
                    reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
                    value: isHovered
                )
                .accessibilityLabel(project.name)
            }

            if isExpanded, !isCompact {
                if transcripts.isEmpty {
                    Text("Sin transcripciones")
                        .font(theme.typography.sidebarItem)
                        .foregroundStyle(theme.colors.foreground.opacity(0.72))
                        .padding(.leading, 44)
                        .padding(.vertical, 5)
                } else {
                    ForEach(transcripts.prefix(5)) { transcript in
                        Button(action: onSelect) {
                            Text(transcript.text)
                                .font(theme.typography.sidebarItem)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.sm) {
                Text(record.text)
                    .font(theme.typography.sidebarItem)
                    .foregroundStyle(theme.colors.foreground.opacity(0.72))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.sm)
            .frame(height: 30)
            .background(isHovered ? theme.colors.hover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
        }
        .buttonStyle(SottoSidebarButtonStyle())
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
            value: isHovered
        )
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
