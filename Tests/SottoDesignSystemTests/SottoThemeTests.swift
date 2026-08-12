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
}

