import SwiftUI

public enum SottoRecordingState: Sendable {
    case idle
    case listening
    case transcribing
}

public struct SottoRecordingPill: View {
    @Environment(\.sottoTheme) private var theme

    private let state: SottoRecordingState
    private let level: Double

    public init(state: SottoRecordingState, level: Double = 0) {
        self.state = state
        self.level = min(max(level, 0), 1)
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: stateIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(stateColor)
                .frame(width: 24, height: 24)
                .background(stateColor.opacity(0.12))
                .clipShape(Circle())

            Text(stateLabel)
                .font(theme.typography.label)
                .foregroundStyle(theme.colors.foreground)

            if state == .listening {
                SottoLevelMeter(level: level)
                    .frame(width: 42)
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background(theme.colors.raisedSurface)
        .overlay {
            Capsule()
                .strokeBorder(theme.colors.border)
        }
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stateLabel)
    }

    private var stateLabel: String {
        switch state {
        case .idle: "Sotto está listo"
        case .listening: "Escuchando"
        case .transcribing: "Transcribiendo"
        }
    }

    private var stateIcon: String {
        switch state {
        case .idle: "waveform"
        case .listening: "mic.fill"
        case .transcribing: "text.cursor"
        }
    }

    private var stateColor: Color {
        switch state {
        case .idle: theme.colors.mutedForeground
        case .listening: theme.colors.accent
        case .transcribing: theme.colors.success
        }
    }
}

private struct SottoLevelMeter: View {
    @Environment(\.sottoTheme) private var theme

    let level: Double

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let threshold = Double(index + 1) / 5
                let activation = max(0.18, min(1, level / threshold))

                Capsule()
                    .fill(theme.colors.accent.opacity(0.35 + activation * 0.65))
                    .frame(width: 3, height: 5 + (CGFloat(activation) * CGFloat(8 + index % 2 * 4)))
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}

