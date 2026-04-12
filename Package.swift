// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SnapMark",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "SnapMark",
            path: "SnapMark",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                // Carbon is not auto-linked via import — must be explicit
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
