import SwiftUI
import XCTest
@testable import SottoDesignSystem

final class SottoThemeTests: XCTestCase {
    func testFoundationDefaultsUseFourPointGrid() {
        let spacing = SottoTheme.Spacing()

        XCTAssertEqual(spacing.xs, 4)
        XCTAssertEqual(spacing.sm, 8)
        XCTAssertEqual(spacing.md, 12)
        XCTAssertEqual(spacing.lg, 16)
        XCTAssertEqual(spacing.xl, 24)
        XCTAssertEqual(spacing.xxl, 32)
    }

    func testFoundationValuesCanBeReplacedWithoutChangingComponents() {
        let spacing = SottoTheme.Spacing(md: 14, lg: 20)
        let radii = SottoTheme.Radii(small: 4, medium: 8, large: 12)
        var theme = SottoTheme.standard

        theme.spacing = spacing
        theme.radii = radii

        XCTAssertEqual(theme.spacing.md, 14)
        XCTAssertEqual(theme.spacing.lg, 20)
        XCTAssertEqual(theme.radii.medium, 8)
    }

    func testComponentVariantsRemainFiniteAndDiscoverable() {
        XCTAssertEqual(SottoButtonVariant.allCases.count, 4)
        XCTAssertEqual(SottoButtonSize.allCases.count, 3)
    }

    func testActionColorPairsPassWCAGAndAPCAForNormalText() {
        let statusPairs = SottoPalette.statusPairs.flatMap { [$0.light, $0.dark] }
        let pairs = SottoPalette.accentPairs
            + [SottoPalette.destructiveAction]
            + SottoPalette.actionPairs
            + statusPairs

        for pair in pairs {
            XCTAssertGreaterThanOrEqual(
                wcagContrast(pair.foreground, pair.background),
                4.5
            )
            XCTAssertGreaterThanOrEqual(
                abs(apcaContrast(pair.foreground, pair.background)),
                60
            )
        }
    }

    func testBeautifulUIReferencePaletteRemainsExact() {
        XCTAssertEqual(SottoPalette.Light.page, SottoSRGB(hex: 0xFAFAFB))
        XCTAssertEqual(SottoPalette.Light.surface, SottoSRGB(hex: 0xFFFFFF))
        XCTAssertEqual(SottoPalette.Light.line, SottoSRGB(hex: 0xECEDEF))
        XCTAssertEqual(SottoPalette.Light.ink, SottoSRGB(hex: 0x1F2124))
        XCTAssertEqual(SottoPalette.Light.accent, SottoSRGB(hex: 0x0285FF))

        XCTAssertEqual(SottoPalette.Dark.page, SottoSRGB(hex: 0x17181A))
        XCTAssertEqual(SottoPalette.Dark.surface, SottoSRGB(hex: 0x232427))
        XCTAssertEqual(SottoPalette.Dark.line, SottoSRGB(hex: 0x2E3033))
        XCTAssertEqual(SottoPalette.Dark.ink, SottoSRGB(hex: 0xF2F3F4))
        XCTAssertEqual(SottoPalette.Dark.accent, SottoSRGB(hex: 0x3D9AFF))
    }

    private func wcagContrast(_ foreground: SottoSRGB, _ background: SottoSRGB) -> Double {
        let values = [wcagLuminance(foreground), wcagLuminance(background)].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }

    private func wcagLuminance(_ color: SottoSRGB) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red)
            + 0.7152 * channel(color.green)
            + 0.0722 * channel(color.blue)
    }

    private func apcaContrast(_ foreground: SottoSRGB, _ background: SottoSRGB) -> Double {
        let text = apcaLuminance(foreground)
        let canvas = apcaLuminance(background)
        if canvas > text {
            let contrast = (pow(canvas, 0.56) - pow(text, 0.57)) * 1.14
            return contrast < 0.1 ? 0 : (contrast - 0.027) * 100
        }
        let contrast = (pow(canvas, 0.65) - pow(text, 0.62)) * 1.14
        return contrast > -0.1 ? 0 : (contrast + 0.027) * 100
    }

    private func apcaLuminance(_ color: SottoSRGB) -> Double {
        var value = 0.2126729 * pow(color.red, 2.4)
            + 0.7151522 * pow(color.green, 2.4)
            + 0.072175 * pow(color.blue, 2.4)
        if value < 0.022 {
            value += pow(0.022 - value, 1.414)
        }
        return value
    }
}
