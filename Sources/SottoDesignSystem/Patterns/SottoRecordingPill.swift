import SwiftUI
import SottoLocalization

public enum SottoRecordingState: Equatable, Sendable {
    case idle
    case listening
    case transcribing
}

public struct SottoRecordingPill: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let state: SottoRecordingState
    private let level: Double

    public init(state: SottoRecordingState, level: Double = 0) {
        self.state = state
        self.level = min(max(level, 0), 1)
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            SottoIcon(stateIcon, size: 13, weight: .medium)
                .foregroundStyle(stateColor)

            Text(stateLabel)
                .font(theme.typography.label)
                .tracking(theme.typography.tracking)
                .foregroundStyle(theme.colors.foreground)

            if state == .listening {
                SottoLevelMeter(level: level)
                    .frame(width: 42)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(stateBackground)
        .clipShape(Capsule())
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.regular),
            value: state
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stateLabel)
    }

    private var stateLabel: String {
        switch state {
        case .idle: SottoLocalization.string("home.dictation.ready")
        case .listening: SottoLocalization.string("home.dictation.listening")
        case .transcribing: SottoLocalization.string("home.dictation.transcribing")
        }
    }

    private var stateIcon: String {
        switch state {
        case .idle: "waveform"
        case .listening: "mic"
        case .transcribing: "text.cursor"
        }
    }

    private var stateColor: Color {
        switch state {
        case .idle: theme.colors.mutedForeground
        case .listening: theme.colors.accent
        case .transcribing: theme.colors.successForeground
        }
    }

    private var stateBackground: Color {
        switch state {
        case .idle: theme.colors.field
        case .listening: theme.colors.accentTint
        case .transcribing: theme.colors.successBackground
        }
    }
}

private struct SottoLevelMeter: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let level: Double

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let threshold = Double(index + 1) / 5
                let activation = max(0.18, min(1, level / threshold))

                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.colors.accent.opacity(0.35 + activation * 0.65))
                    .frame(width: 3, height: 5 + (CGFloat(activation) * CGFloat(8 + index % 2 * 4)))
            }
        }
        .frame(height: 18)
        .animation(reduceMotion ? nil : .linear(duration: theme.motion.fast), value: level)
        .accessibilityHidden(true)
    }
}
