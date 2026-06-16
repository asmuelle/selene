// swift-tools-version: 6.0
// Selene — umbrella package for all on-device modules.
// The app shell (App/, generated Selene.xcodeproj) consumes these products;
// `swift test` runs the entire core suite on macOS with zero simulators required.
import PackageDescription

let package = Package(
    name: "SelenePackages",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SeleneCore", targets: ["SeleneCore"]),
        .library(name: "CycleEngine", targets: ["CycleEngine"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "InsightKit", targets: ["InsightKit"]),
        .library(name: "StripVision", targets: ["StripVision"]),
        .library(name: "ContentPack", targets: ["ContentPack"]),
        .library(name: "Paywall", targets: ["Paywall"]),
        .library(name: "SeleneUI", targets: ["SeleneUI"]),
        .library(name: "DoctorVisit", targets: ["DoctorVisit"]),
        .library(name: "VoiceCapture", targets: ["VoiceCapture"]),
    ],
    dependencies: [
        // The single allowed third-party dependency (see AGENTS.md invariant #2).
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        // MARK: Sources

        .target(
            name: "SeleneCore",
            path: "Packages/SeleneCore/Sources"
        ),
        .target(
            name: "CycleEngine",
            dependencies: ["SeleneCore"],
            path: "Packages/CycleEngine/Sources"
        ),
        .target(
            name: "Persistence",
            dependencies: [
                "SeleneCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Packages/Persistence/Sources"
        ),
        .target(
            name: "InsightKit",
            dependencies: ["SeleneCore", "CycleEngine", "ContentPack"],
            path: "Packages/InsightKit/Sources"
        ),
        .target(
            name: "StripVision",
            dependencies: ["SeleneCore"],
            path: "Packages/StripVision/Sources"
        ),
        .target(
            name: "ContentPack",
            dependencies: ["SeleneCore"],
            path: "Packages/ContentPack/Sources"
        ),
        .target(
            name: "Paywall",
            dependencies: ["SeleneCore"],
            path: "Packages/Paywall/Sources"
        ),
        .target(
            name: "SeleneUI",
            dependencies: ["SeleneCore", "CycleEngine"],
            path: "Packages/SeleneUI/Sources"
        ),
        .target(
            name: "DoctorVisit",
            dependencies: ["SeleneCore", "CycleEngine", "ContentPack"],
            path: "Packages/DoctorVisit/Sources"
        ),
        .target(
            name: "VoiceCapture",
            dependencies: ["SeleneCore", "InsightKit"],
            path: "Packages/VoiceCapture/Sources"
        ),

        // MARK: Test support

        // The URLProtocol egress harness (in-process substitute for a mitmproxy
        // capture — see DESIGN.md). Test-only: never a dependency of any
        // product the app links.
        .target(
            name: "EgressGuardKit",
            path: "Tests/EgressGuard/Harness"
        ),

        // MARK: Tests

        .testTarget(
            name: "SeleneCoreTests",
            dependencies: ["SeleneCore"],
            path: "Packages/SeleneCore/Tests"
        ),
        .testTarget(
            name: "CycleEngineTests",
            dependencies: ["CycleEngine", "SeleneCore"],
            path: "Packages/CycleEngine/Tests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence", "SeleneCore"],
            path: "Packages/Persistence/Tests"
        ),
        .testTarget(
            name: "InsightKitTests",
            dependencies: ["InsightKit", "CycleEngine", "ContentPack", "SeleneCore"],
            path: "Packages/InsightKit/Tests"
        ),
        .testTarget(
            name: "StripVisionTests",
            dependencies: ["StripVision", "SeleneCore"],
            path: "Packages/StripVision/Tests"
        ),
        .testTarget(
            name: "ContentPackTests",
            dependencies: ["ContentPack", "SeleneCore"],
            path: "Packages/ContentPack/Tests"
        ),
        .testTarget(
            name: "PaywallTests",
            dependencies: ["Paywall", "SeleneCore", "EgressGuardKit"],
            path: "Packages/Paywall/Tests"
        ),
        .testTarget(
            name: "SeleneUITests",
            dependencies: ["SeleneUI", "CycleEngine", "SeleneCore"],
            path: "Packages/SeleneUI/Tests"
        ),
        .testTarget(
            name: "DoctorVisitTests",
            dependencies: ["DoctorVisit", "CycleEngine", "ContentPack", "SeleneCore"],
            path: "Packages/DoctorVisit/Tests"
        ),
        .testTarget(
            name: "VoiceCaptureTests",
            dependencies: ["VoiceCapture", "InsightKit", "SeleneCore"],
            path: "Packages/VoiceCapture/Tests"
        ),
        .testTarget(
            name: "RepoGuardTests",
            path: "Tests/RepoGuards"
        ),
        .testTarget(
            name: "EgressGuardTests",
            dependencies: [
                "EgressGuardKit",
                "SeleneCore",
                "CycleEngine",
                "Persistence",
                "InsightKit",
                "ContentPack",
                "Paywall",
                "SeleneUI",
                "DoctorVisit",
                "VoiceCapture",
            ],
            path: "Tests/EgressGuard/Flow"
        ),
    ]
)
