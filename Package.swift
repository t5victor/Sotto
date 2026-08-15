// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sotto",
    defaultLocalization: "es",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Sotto", targets: ["Sotto"]),
        .executable(name: "SottoDoctor", targets: ["SottoDoctor"]),
        .library(name: "SottoLocalization", targets: ["SottoLocalization"]),
        .library(name: "SottoDesignSystem", targets: ["SottoDesignSystem"]),
        .library(name: "SottoCore", targets: ["SottoCore"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "667181a368da13b3a9178e310414e9dcbe8f23ce"
        ),
    ],
    targets: [
        .target(
            name: "SottoAudioRingC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SottoLocalization",
            resources: [
                .process("Resources/Localization"),
            ]
        ),
        .target(
            name: "SottoDesignSystem",
            dependencies: ["SottoLocalization"]
        ),
        .target(
            name: "SottoCore",
            dependencies: [
                "SottoAudioRingC",
                "SottoLocalization",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .executableTarget(
            name: "Sotto",
            dependencies: [
                "SottoCore",
                "SottoDesignSystem",
                "SottoLocalization",
            ],
            exclude: [
                "Resources/AppIcon.icns",
                "Resources/Info.plist",
                "Resources/Sotto.entitlements",
                "Resources/ThirdPartyNotices.txt",
            ],
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/FontLicenses"),
                .process("Resources/Localization"),
            ]
        ),
        .executableTarget(
            name: "SottoDoctor",
            dependencies: ["SottoCore"]
        ),
        .testTarget(
            name: "SottoDesignSystemTests",
            dependencies: ["SottoDesignSystem"]
        ),
        .testTarget(
            name: "SottoCoreTests",
            dependencies: ["SottoCore", "SottoAudioRingC", "SottoLocalization"]
        ),
    ]
)
