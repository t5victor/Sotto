import SwiftUI

public struct SottoPixelLoader: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let color: Color?

    public init(color: Color? = nil) {
        self.color = color
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.09, paused: reduceMotion)) { timeline in
            let activeIndex = reduceMotion
                ? 4
                : Int(timeline.date.timeIntervalSinceReferenceDate * 8) % 9

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(3), spacing: 1.5), count: 3), spacing: 1.5) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 0.7)
                        .fill(color ?? theme.colors.foreground)
                        .frame(width: 3, height: 3)
                        .opacity(index == activeIndex ? 1 : 0.16)
                }
            }
            .animation(.linear(duration: 0.09), value: activeIndex)
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }
}

public struct SottoActivityLabel: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            SottoPixelLoader()
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                Text(text)
                    .font(theme.typography.label)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(textStyle(at: timeline.date))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    private func textStyle(at date: Date) -> LinearGradient {
        let phase = reduceMotion
            ? 0.5
            : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
        return LinearGradient(
            colors: [
                theme.colors.mutedForeground,
                theme.colors.foreground,
                theme.colors.mutedForeground,
            ],
            startPoint: UnitPoint(x: phase - 0.8, y: 0.5),
            endPoint: UnitPoint(x: phase + 0.8, y: 0.5)
        )
    }
}
