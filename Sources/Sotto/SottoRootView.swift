import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

enum SottoDestination: Hashable, Identifiable {
    case home
    case history
    case models
    case vocabulary
    case text
    case shortcuts
    case appearance
    case privacy
    case project(UUID)
    case transcript(UUID)

    var id: String {
        switch self {
        case .home: "home"
        case .history: "history"
        case .models: "models"
        case .vocabulary: "vocabulary"
        case .text: "text"
        case .shortcuts: "shortcuts"
        case .appearance: "appearance"
        case .privacy: "privacy"
        case .project(let id): "project-\(id.uuidString)"
        case .transcript(let id): "transcript-\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .home: SottoLocalization.string("navigation.home")
        case .history: SottoLocalization.string("navigation.history")
        case .models: SottoLocalization.string("navigation.models")
        case .vocabulary: SottoLocalization.string("navigation.vocabulary")
        case .text: SottoLocalization.string("home.section.text")
        case .shortcuts: SottoLocalization.string("navigation.shortcuts")
        case .appearance: SottoLocalization.string("navigation.appearance")
        case .privacy: SottoLocalization.string("navigation.privacy")
        case .project: SottoLocalization.string("navigation.project")
        case .transcript: SottoLocalization.string("transcription.detail.title")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .history: "clock"
        case .models: "waveform"
        case .vocabulary: "character.book.closed"
        case .text: "textformat"
        case .shortcuts: "command"
        case .appearance: "circle.lefthalf.filled"
        case .privacy: "lock"
        case .project: "folder"
        case .transcript: "doc.text"
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
                .frame(minWidth: 76, idealWidth: 196, maxWidth: 280, maxHeight: .infinity)

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
        .onChange(of: model.history) { _, history in
            guard case .transcript(let recordID) = selection,
                  !history.contains(where: { $0.id == recordID })
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
        case .text:
            SottoTextView(model: model)
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
        case .transcript(let recordID):
            if let record = model.history.first(where: { $0.id == recordID }) {
                SottoTranscriptDetailView(
                    record: record,
                    model: model,
                    onBack: {
                        if let projectID = record.projectID,
                           model.projects.contains(where: { $0.id == projectID }) {
                            selection = .project(projectID)
                        } else {
                            selection = .history
                        }
                    }
                )
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
        .text,
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
                        title: SottoLocalization.string("sidebar.new_transcription"),
                        systemImage: "square.and.pencil",
                        isCompact: isCompact
                    ) {
                        selection = .home
                        model.toggleDictation()
                    }
                    .padding(.top, isCompact ? theme.spacing.sm : theme.spacing.md)

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
                        SottoSidebarSection(title: SottoLocalization.string("sidebar.pinned")) {
                            ForEach(pinnedRecords.prefix(4)) { record in
                                SottoRecentRow(record: record, isSelected: selection == .transcript(record.id)) {
                                    selection = .transcript(record.id)
                                }
                            }
                        }
                        .padding(.top, theme.spacing.md)
                    }

                    projectsSection(isCompact: isCompact)

                    recentsSection(isCompact: isCompact)
                        .padding(.top, isCompact ? theme.spacing.sm : theme.spacing.md)

                    Spacer(minLength: theme.spacing.xxl)
                }
                .padding(.top, isCompact ? theme.spacing.xs : theme.spacing.md)
                .padding(.bottom, theme.spacing.md)
            }
            .padding(.horizontal, isCompact ? theme.spacing.xs : theme.spacing.md)
        }
        .background(theme.colors.canvas)
        .sheet(isPresented: $isShowingSearch) {
            SottoHistorySearchView(model: model, selection: $selection)
                .sottoTheme(theme)
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
            .sottoTheme(theme)
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
                Text(SottoLocalization.string("app.name"))
                    .font(theme.typography.sidebarTitle)
                    .foregroundStyle(theme.colors.foreground)

                Spacer(minLength: theme.spacing.sm)
            } else {
                Spacer(minLength: 0)
            }

            SottoSidebarIconButton(
                systemImage: "magnifyingglass",
                help: SottoLocalization.string("common.search")
            ) {
                isShowingSearch = true
            }

            Menu {
                ForEach(configuration) { destination in
                    Button(destination.title) {
                        selection = destination
                    }
                }
            } label: {
                SottoSidebarIconLabel(systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .tint(theme.colors.mutedForeground)
            .buttonStyle(SottoSidebarButtonStyle())
            .frame(width: 24, height: 24)
            .help(SottoLocalization.string("common.settings"))
            .accessibilityLabel(SottoLocalization.string("common.settings"))

            if isCompact {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28)
        .padding(.horizontal, isCompact ? 0 : theme.spacing.xs)
    }

    private func recentsSection(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(
                    reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast)
                ) {
                    isRecentsExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: theme.spacing.xs) {
                    if isCompact {
                        Spacer(minLength: 0)
                    }

                    if !isCompact {
                        Text(SottoLocalization.string("sidebar.recents"))
                            .font(theme.typography.sidebarSection)
                            .foregroundStyle(theme.colors.mutedForeground.opacity(0.88))
                    }

                    SottoIcon(
                        isRecentsExpanded ? "chevron.down" : "chevron.right",
                        size: isCompact ? 12 : 10,
                        weight: .semibold
                    )
                    .foregroundStyle(theme.colors.mutedForeground.opacity(0.82))
                    .frame(width: 12, height: 16)

                    Spacer(minLength: isCompact ? 0 : theme.spacing.sm)

                    if !isCompact, !model.history.isEmpty {
                        Circle()
                            .fill(theme.colors.accent)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.horizontal, theme.spacing.xs)
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(SottoSidebarButtonStyle())

            if isRecentsExpanded, !isCompact {
                ForEach(model.history.prefix(4)) { record in
                    SottoRecentRow(record: record, isSelected: selection == .transcript(record.id)) {
                        selection = .transcript(record.id)
                    }
                }
            }
        }
    }

    private func projectsSection(isCompact: Bool) -> some View {
        SottoSidebarSection(
            title: SottoLocalization.string("sidebar.projects"),
            actionTitle: SottoLocalization.string("common.new_project"),
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
                    selectedTranscriptID: selectedTranscriptID,
                    onSelect: {
                        selection = .project(project.id)
                    },
                    onSelectTranscript: { transcriptID in
                        selection = .transcript(transcriptID)
                    },
                    onToggleExpanded: {
                        toggleProject(project.id)
                    }
                )
            }

            if model.projects.isEmpty, !isCompact {
                Button {
                    beginProjectCreation()
                } label: {
                    Text(SottoLocalization.string("sidebar.first_project"))
                    .font(theme.typography.sidebarItem)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, theme.spacing.xs)
                    .frame(height: 28)
                }
                .buttonStyle(SottoSidebarButtonStyle())
            }
        }
        .padding(.top, isCompact ? theme.spacing.sm : theme.spacing.md)
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

    private var selectedTranscriptID: UUID? {
        guard case .transcript(let recordID) = selection else { return nil }
        return recordID
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
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if !isCompact {
                    Text(title)
                        .font(theme.typography.sidebarSection)
                        .foregroundStyle(theme.colors.mutedForeground.opacity(0.88))

                    Spacer(minLength: theme.spacing.sm)
                } else {
                    Spacer(minLength: 0)
                }

                if let actionTitle, let action {
                    Button(action: action) {
                        if let actionSystemImage {
                            SottoIcon(actionSystemImage, size: isCompact ? 14 : 13, weight: .regular)
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

                if isCompact {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, theme.spacing.xs)
            .frame(height: 26)

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
            SottoSidebarIconLabel(systemImage: systemImage, isHovered: isHovered)
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

private struct SottoSidebarIconLabel: View {
    let systemImage: String
    var isHovered = false

    @Environment(\.sottoTheme) private var theme

    var body: some View {
        SottoIcon(systemImage, size: 14, weight: .regular)
            .foregroundStyle(isHovered ? theme.colors.foreground : theme.colors.mutedForeground)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
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
            HStack(spacing: theme.spacing.xs) {
                SottoIcon(systemImage, size: isCompact ? 15 : 14, weight: .regular)
                    .foregroundStyle(theme.colors.foreground.opacity(0.72))
                    .frame(width: isCompact ? 24 : 18)

                if !isCompact {
                    Text(title)
                        .font(theme.typography.sidebarItem)
                        .foregroundStyle(theme.colors.foreground.opacity(0.72))

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            .padding(.horizontal, isCompact ? 0 : theme.spacing.xs)
            .frame(height: 28)
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
            HStack(spacing: theme.spacing.xs) {
                SottoIcon(destination.systemImage, size: isCompact ? 15 : 14, weight: .regular)
                    .foregroundStyle(theme.colors.foreground.opacity(0.72))
                    .frame(width: isCompact ? 24 : 18)

                if !isCompact {
                    Text(destination.title)
                        .font(theme.typography.sidebarItem)
                        .foregroundStyle(theme.colors.foreground.opacity(0.72))

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            .padding(.horizontal, isCompact ? 0 : theme.spacing.xs)
            .frame(height: 28)
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
    let selectedTranscriptID: UUID?
    let onSelect: () -> Void
    let onSelectTranscript: (UUID) -> Void
    let onToggleExpanded: () -> Void

    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                if !isCompact {
                    Button(action: onToggleExpanded) {
                        SottoIcon(isExpanded ? "chevron.down" : "chevron.right", size: 10, weight: .semibold)
                            .foregroundStyle(theme.colors.subtleForeground)
                            .frame(width: 16, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SottoSidebarButtonStyle())
                }

                Button(action: onSelect) {
                    HStack(spacing: theme.spacing.sm) {
                        SottoIcon(project.icon, size: isCompact ? 15 : 14)
                            .foregroundStyle(project.accent.color)
                            .frame(width: isCompact ? 24 : 18)

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
                    .frame(height: 28)
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
                    Text(SottoLocalization.string("sidebar.no_transcriptions"))
                        .font(theme.typography.sidebarItem)
                        .foregroundStyle(theme.colors.foreground.opacity(0.72))
                        .padding(.leading, 38)
                        .padding(.vertical, 4)
                } else {
                    ForEach(transcripts.prefix(5)) { transcript in
                        Button {
                            onSelectTranscript(transcript.id)
                        } label: {
                            Text(transcript.text)
                                .font(theme.typography.sidebarItem)
                                .foregroundStyle(
                                    theme.colors.foreground.opacity(
                                        selectedTranscriptID == transcript.id ? 1 : 0.72
                                    )
                                )
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 38)
                                .padding(.trailing, theme.spacing.xs)
                                .frame(height: 24)
                                .background(
                                    selectedTranscriptID == transcript.id
                                        ? theme.colors.hoverStrong
                                        : .clear
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous)
                                )
                        }
                        .buttonStyle(SottoSidebarButtonStyle())
                    }
                }
            }
        }
        .contextMenu {
            Text(
                SottoLocalization.count(
                    "sidebar.transcription_count.one",
                    "sidebar.transcription_count.other",
                    transcripts.count
                )
            )
            Divider()
            Button(SottoLocalization.string("common.open_project"), action: onSelect)
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
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.xs) {
                Text(record.text)
                    .font(theme.typography.sidebarItem)
                    .foregroundStyle(theme.colors.foreground.opacity(0.72))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.xs)
            .frame(height: 28)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
        }
        .buttonStyle(SottoSidebarButtonStyle())
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
            value: isHovered
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: Color {
        if isSelected { return theme.colors.hoverStrong }
        if isHovered { return theme.colors.hover }
        return .clear
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
