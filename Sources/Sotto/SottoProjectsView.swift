import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

struct SottoProjectView: View {
    @ObservedObject var model: SottoAppModel
    let project: SottoProject

    @Environment(\.sottoTheme) private var theme
    @State private var isRenaming = false
    @State private var isConfirmingDeletion = false
    @State private var draftName = ""

    private var records: [TranscriptionRecord] {
        model.history.filter { $0.projectID == project.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                SottoReveal {
                    HStack(alignment: .top, spacing: theme.spacing.md) {
                        SottoIcon(project.icon, size: 20, weight: .medium)
                            .foregroundStyle(project.accent.color)
                            .frame(width: 28, height: 28)

                        SottoPageHeader(
                            title: project.name,
                            description: records.isEmpty
                                ? SottoLocalization.string("project.empty_header_description")
                                : SottoLocalization.format(
                                    "project.records_description",
                                    Int64(records.count)
                                )
                        )

                        Spacer(minLength: theme.spacing.lg)

                        HStack(spacing: theme.spacing.xs) {
                            Button {
                                draftName = project.name
                                isRenaming = true
                            } label: {
                                SottoIcon("pencil", size: 13)
                            }
                            .buttonStyle(.sotto(.ghost, size: .small))
                            .help(SottoLocalization.string("project.rename"))

                            Button {
                                isConfirmingDeletion = true
                            } label: {
                                SottoIcon("trash", size: 13)
                            }
                            .buttonStyle(.sotto(.ghost, size: .small))
                            .help(SottoLocalization.string("project.delete"))
                        }
                    }
                }

                if records.isEmpty {
                    SottoCard(style: .muted) {
                        SottoEmptyState(
                            systemImage: "folder",
                            title: SottoLocalization.string("project.empty_title"),
                            description: SottoLocalization.string("project.empty_description")
                        )
                    }
                } else {
                    SottoReveal(delay: 0.04) {
                        LazyVStack(spacing: 0) {
                            ForEach(records) { record in
                                SottoTranscriptRow(record: record, model: model, projectID: project.id)
                                if record.id != records.last?.id {
                                    SottoDivider()
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(theme.spacing.xxl)
        }
        .background(theme.colors.surface)
        .alert(SottoLocalization.string("project.rename"), isPresented: $isRenaming) {
            TextField(SottoLocalization.string("project.name_placeholder"), text: $draftName)
            Button(SottoLocalization.string("common.save")) {
                model.updateProject(
                    id: project.id,
                    name: draftName,
                    icon: project.icon,
                    accent: project.accent
                )
            }
            Button(SottoLocalization.string("common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            SottoLocalization.format("project.confirm_delete_title", project.name),
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button(SottoLocalization.string("project.delete"), role: .destructive) {
                model.deleteProject(id: project.id)
            }
            Button(SottoLocalization.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(SottoLocalization.string("project.delete_message"))
        }
    }
}

struct SottoTranscriptRow: View {
    let record: TranscriptionRecord
    @ObservedObject var model: SottoAppModel
    let projectID: UUID?

    @Environment(\.sottoTheme) private var theme
    @State private var isConfirmingDeletion = false
    @State private var didCopy = false
    @State private var copyResetTask: Task<Void, Never>?

    private var recordProject: SottoProject? {
        model.projects.first(where: { $0.id == record.projectID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(alignment: .top, spacing: theme.spacing.lg) {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    recordMetadata

                    Text(record.text)
                        .font(theme.typography.body)
                        .tracking(theme.typography.tracking)
                        .foregroundStyle(theme.colors.foreground)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: theme.spacing.md)

                actionBar
            }
        }
        .padding(.vertical, theme.spacing.xl)
        .confirmationDialog(
            SottoLocalization.string("history.record.delete_confirmation"),
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button(SottoLocalization.string("common.delete"), role: .destructive) {
                model.removeHistory(id: record.id)
            }
            Button(SottoLocalization.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(SottoLocalization.string("history.record.delete_message"))
        }
        .onDisappear {
            copyResetTask?.cancel()
        }
    }

    private var recordMetadata: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(record.createdAt, format: .dateTime.day().month().hour().minute())
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.mutedForeground)

            if let app = record.targetApplication {
                Text(app)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.subtleForeground)
            }

            Text(record.insertionOutcome.displayName)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.subtleForeground)

            if let recordProject {
                HStack(spacing: theme.spacing.xxs) {
                    SottoIcon(recordProject.icon, size: 11)
                        .foregroundStyle(recordProject.accent.color)
                    Text(recordProject.name)
                }
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.subtleForeground)
            }
        }
        .lineLimit(1)
    }

    private var actionBar: some View {
        HStack(spacing: 2) {
            SottoHistoryActionButton(
                systemImage: record.isPinned ? "pin.fill" : "pin",
                help: SottoLocalization.string(record.isPinned ? "project.unpin" : "project.pin"),
                isActive: record.isPinned,
                activeColor: theme.colors.accentInk
            ) {
                model.toggleHistoryPin(id: record.id)
            }

            moveMenu

            SottoHistoryActionButton(
                systemImage: didCopy ? "checkmark" : "doc.on.doc",
                help: SottoLocalization.string(didCopy ? "history.record.copied" : "common.copy"),
                isActive: didCopy,
                activeColor: theme.colors.successForeground
            ) {
                copyRecord()
            }

            SottoHistoryActionButton(
                systemImage: "trash",
                help: SottoLocalization.string("common.delete"),
                isDestructive: true
            ) {
                isConfirmingDeletion = true
            }
        }
        .padding(3)
        .background(theme.colors.field)
        .overlay {
            Capsule()
                .strokeBorder(theme.colors.border, lineWidth: 1)
        }
        .clipShape(Capsule())
    }

    private var moveMenu: some View {
        Menu {
            Button {
                model.moveHistory(id: record.id, to: nil)
            } label: {
                historyProjectMenuLabel(
                    name: SottoLocalization.string("project.unassigned"),
                    systemImage: "tray",
                    isSelected: record.projectID == nil
                )
            }

            if !model.projects.isEmpty {
                Divider()

                ForEach(model.projects.filter { $0.id != projectID }) { project in
                    Button {
                        model.moveHistory(id: record.id, to: project.id)
                    } label: {
                        historyProjectMenuLabel(
                            name: project.name,
                            systemImage: project.icon,
                            isSelected: record.projectID == project.id
                        )
                    }
                }
            }
        } label: {
            SottoHistoryActionLabel(
                systemImage: "folder",
                isActive: recordProject != nil,
                activeColor: recordProject?.accent.color ?? theme.colors.accentInk
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help(SottoLocalization.string("project.move"))
        .accessibilityLabel(SottoLocalization.string("project.move"))
    }

    private func historyProjectMenuLabel(
        name: String,
        systemImage: String,
        isSelected: Bool
    ) -> some View {
        HStack {
            SottoIcon(systemImage, size: 14)
            Text(name)
            if isSelected {
                Spacer(minLength: theme.spacing.lg)
                SottoIcon("checkmark", size: 12, weight: .semibold)
            }
        }
    }

    private func copyRecord() {
        model.copyToPasteboard(record.text)
        didCopy = true
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            didCopy = false
        }
    }
}

private struct SottoHistoryActionButton: View {
    let systemImage: String
    let help: String
    var isActive = false
    var activeColor: Color? = nil
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SottoHistoryActionLabel(
                systemImage: systemImage,
                isActive: isActive,
                activeColor: activeColor,
                isDestructive: isDestructive
            )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct SottoHistoryActionLabel: View {
    let systemImage: String
    var isActive = false
    var activeColor: Color? = nil
    var isDestructive = false

    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        SottoIcon(systemImage, size: 14, weight: .medium)
            .foregroundStyle(foregroundColor)
            .frame(width: 30, height: 30)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
            .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1)
            .onHover { isHovered = $0 }
            .animation(
                reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
                value: isHovered
            )
    }

    private var foregroundColor: Color {
        if isDestructive {
            return isHovered ? theme.colors.destructiveForeground : theme.colors.mutedForeground
        }
        if isActive {
            return activeColor ?? theme.colors.accentInk
        }
        return isHovered ? theme.colors.foreground : theme.colors.mutedForeground
    }

    private var backgroundColor: Color {
        if isActive { return (activeColor ?? theme.colors.accent).opacity(0.14) }
        return isHovered ? theme.colors.hoverStrong : .clear
    }
}

struct SottoHistorySearchView: View {
    @ObservedObject var model: SottoAppModel
    @Binding var selection: SottoDestination
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sottoTheme) private var theme
    @State private var query = ""

    private var results: [TranscriptionRecord] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return Array(model.history.prefix(20)) }
        return model.history.filter { record in
            record.text.localizedCaseInsensitiveContains(normalizedQuery)
                || record.rawText.localizedCaseInsensitiveContains(normalizedQuery)
                || (record.targetApplication?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack {
                Text(SottoLocalization.string("project.search_title"))
                    .font(theme.typography.pageTitle)
                Spacer()
                Button(SottoLocalization.string("common.close")) { dismiss() }
                    .buttonStyle(.sotto(.ghost, size: .small))
            }

            TextField(SottoLocalization.string("project.search_placeholder"), text: $query)
                .textFieldStyle(.sotto)

            if results.isEmpty {
                SottoEmptyState(
                    systemImage: "magnifyingglass",
                    title: SottoLocalization.string("project.search_no_results"),
                    description: SottoLocalization.string("project.search_no_results_description")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(results) { record in
                            Button {
                                selection = record.projectID.map(SottoDestination.project) ?? .history
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                                    Text(record.text)
                                        .font(theme.typography.body)
                                        .foregroundStyle(theme.colors.foreground)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(record.createdAt, format: .dateTime.day().month().hour().minute())
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colors.subtleForeground)
                                }
                                .padding(.vertical, theme.spacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if record.id != results.last?.id {
                                SottoDivider()
                            }
                        }
                    }
                }
            }
        }
        .padding(theme.spacing.xl)
        .frame(width: 560, height: 500)
        .background(theme.colors.surface)
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
