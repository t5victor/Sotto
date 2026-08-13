import SottoCore
import SottoDesignSystem
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
                                ? "Las transcripciones que guardes aquí aparecerán en este proyecto."
                                : "\(records.count) transcripciones organizadas en este proyecto."
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
                            .help("Renombrar proyecto")

                            Button {
                                isConfirmingDeletion = true
                            } label: {
                                SottoIcon("trash", size: 13)
                            }
                            .buttonStyle(.sotto(.ghost, size: .small))
                            .help("Eliminar proyecto")
                        }
                    }
                }

                if records.isEmpty {
                    SottoCard(style: .muted) {
                        SottoEmptyState(
                            systemImage: "folder",
                            title: "Proyecto vacío",
                            description: "Desde Historial puedes mover cualquier transcripción a este proyecto."
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
        .alert("Renombrar proyecto", isPresented: $isRenaming) {
            TextField("Nombre del proyecto", text: $draftName)
            Button("Guardar") {
                model.updateProject(
                    id: project.id,
                    name: draftName,
                    icon: project.icon,
                    accent: project.accent
                )
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog(
            "¿Eliminar \(project.name)?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Eliminar proyecto", role: .destructive) {
                model.deleteProject(id: project.id)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Las transcripciones se conservarán en Historial, sin proyecto.")
        }
    }
}

struct SottoTranscriptRow: View {
    let record: TranscriptionRecord
    @ObservedObject var model: SottoAppModel
    let projectID: UUID?

    @Environment(\.sottoTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
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

                Spacer(minLength: theme.spacing.sm)

                Button {
                    model.toggleHistoryPin(id: record.id)
                } label: {
                    SottoIcon(record.isPinned ? "pin.fill" : "pin", size: 13)
                        .foregroundStyle(record.isPinned ? theme.colors.accentInk : theme.colors.subtleForeground)
                }
                .buttonStyle(.sotto(.ghost, size: .small))
                .help(record.isPinned ? "Desfijar" : "Fijar")

                Menu {
                    Button("Sin proyecto") {
                        model.moveHistory(id: record.id, to: nil)
                    }

                    if !model.projects.isEmpty {
                        Divider()
                        ForEach(model.projects.filter { $0.id != projectID }) { project in
                            Button {
                                model.moveHistory(id: record.id, to: project.id)
                            } label: {
                                Label(project.name, systemImage: project.icon)
                            }
                        }
                    }
                } label: {
                    SottoIcon("folder", size: 13)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 26, height: 26)
                .help("Mover a proyecto")

                Button {
                    model.copyToPasteboard(record.text)
                } label: {
                    SottoIcon("doc.on.doc", size: 13)
                }
                .buttonStyle(.sotto(.ghost, size: .small))
                .help("Copiar")

                Button {
                    model.removeHistory(id: record.id)
                } label: {
                    SottoIcon("trash", size: 13)
                }
                .buttonStyle(.sotto(.ghost, size: .small))
                .help("Eliminar")
            }

            Text(record.text)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.foreground)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, theme.spacing.md)
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
                Text("Buscar transcripciones")
                    .font(theme.typography.pageTitle)
                Spacer()
                Button("Cerrar") { dismiss() }
                    .buttonStyle(.sotto(.ghost, size: .small))
            }

            TextField("Escribe para buscar…", text: $query)
                .textFieldStyle(.sotto)

            if results.isEmpty {
                SottoEmptyState(
                    systemImage: "magnifyingglass",
                    title: "Sin resultados",
                    description: "Prueba con otras palabras."
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
