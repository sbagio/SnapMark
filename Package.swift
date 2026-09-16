// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SnapMark",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        // Testable business logic — no Carbon dependency
        .target(
            name: "SnapMarkCore",
            path: "SnapMarkCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // Main app executable — UI, capture, hotkey
        .executableTarget(
            name: "SnapMark",
            dependencies: ["SnapMarkCore"],
            path: "SnapMark",
            // The app bundle's resources are assembled by scripts/build-app.sh, not
            // SwiftPM. Excluding them stops SwiftPM invoking actool on the asset
            // catalog, which requires a full Xcode that `swift build` should not need.
            exclude: [
                "Info.plist",
                "Resources/SnapMark.entitlements",
                "Resources/Assets.xcassets",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),

        // Test runner — plain executable, no framework needed.
        // Top-level Swift 6 code runs on @MainActor, so actor-isolated
        // types (AnnotationStore, HistoryStore) are directly testable.
        .executableTarget(
            name: "SnapMarkTests",
            dependencies: ["SnapMarkCore"],
            path: "Tests/SnapMarkTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
