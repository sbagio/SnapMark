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
