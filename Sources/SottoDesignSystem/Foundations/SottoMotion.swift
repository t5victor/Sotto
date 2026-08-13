import SwiftUI

public struct SottoReveal<Content: View>: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private let delay: Double
    private let content: Content

    public init(delay: Double = 0, @ViewBuilder content: () -> Content) {
        self.delay = delay
        self.content = content()
    }

    public var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : 8)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(
                    .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.reveal)
                        .delay(reduceMotion ? 0 : delay)
                ) {
                    isVisible = true
                }
            }
    }
}
