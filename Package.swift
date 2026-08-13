// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sotto",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Sotto", targets: ["Sotto"]),
        .executable(name: "SottoDoctor", targets: ["SottoDoctor"]),
        .library(name: "SottoDesignSystem", targets: ["SottoDesignSystem"]),
        .library(name: "SottoCore", targets: ["SottoCore"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            exact: "0.15.5"
        ),
    ],
    targets: [
        .target(
            name: "SottoAudioRingC",
            publicHeadersPath: "include"
        ),
        .target(name: "SottoDesignSystem"),
        .target(
            name: "SottoCore",
            dependencies: [
                "SottoAudioRingC",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .executableTarget(
            name: "Sotto",
            dependencies: [
                "SottoCore",
                "SottoDesignSystem",
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
            dependencies: ["SottoCore", "SottoAudioRingC"]
        ),
    ]
)
