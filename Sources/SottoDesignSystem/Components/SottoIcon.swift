import SwiftUI

/// A single icon entry point keeps size, weight and monochrome rendering
/// consistent with Beautiful UI's 24-point outline icon language.
public struct SottoIcon: View {
    private let systemName: String
    private let size: CGFloat
    private let weight: Font.Weight

    public init(_ systemName: String, size: CGFloat = 14, weight: Font.Weight = .regular) {
        self.systemName = systemName
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: size, weight: weight))
            .frame(width: size + 4, height: size + 4)
            .accessibilityHidden(true)
    }
}
