import Foundation
import Testing

/// Repository-level invariant guards (AGENTS.md invariants #1 and #2).
/// These tests read the source tree itself, so violating an invariant anywhere
/// in `Packages/` fails the suite — the privacy proof runs on every `swift test`.
@Suite("Repo guards")
struct RepoGuardTests {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // RepoGuards
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repo root

    /// Networking primitives that must never appear outside `Paywall/`.
    static let bannedNetworkingTokens = [
        "import Network",
        "URLSession",
        "NWConnection",
        "NWListener",
        "CFSocket",
        "import CFNetwork",
        "NSURLConnection",
    ]

    @Test("no networking primitive outside Paywall (invariant #1: zero egress)")
    func noNetworkingOutsidePaywall() throws {
        // Arrange
        let packagesURL = Self.repoRoot.appendingPathComponent("Packages")
        let swiftFiles = try Self.swiftFiles(under: packagesURL)
        #expect(!swiftFiles.isEmpty, "guard must actually see the package sources")

        // Act & Assert
        for file in swiftFiles {
            let path = file.path
            if path.contains("/Packages/Paywall/") { continue }
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in Self.bannedNetworkingTokens where source.contains(token) {
                Issue.record("networking token '\(token)' found outside Paywall in \(path)")
            }
        }
    }

    @Test("App shell contains no networking primitives either")
    func noNetworkingInAppShell() throws {
        let appURL = Self.repoRoot.appendingPathComponent("App")
        guard FileManager.default.fileExists(atPath: appURL.path) else { return }
        for file in try Self.swiftFiles(under: appURL) {
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in Self.bannedNetworkingTokens where source.contains(token) {
                Issue.record("networking token '\(token)' found in App shell: \(file.path)")
            }
        }
    }

    @Test("repo-level test targets contain no networking primitives either")
    func noNetworkingInRepoTests() throws {
        // The egress harness (Tests/EgressGuard) deliberately uses URLProtocol —
        // an interception point, not an egress primitive — and must itself stay
        // free of session/socket APIs. Only this guard suite is exempt, because
        // it names the banned tokens as string literals.
        let testsURL = Self.repoRoot.appendingPathComponent("Tests")
        for file in try Self.swiftFiles(under: testsURL) {
            if file.path.contains("/Tests/RepoGuards/") { continue }
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in Self.bannedNetworkingTokens where source.contains(token) {
                Issue.record("networking token '\(token)' found in test tree: \(file.path)")
            }
        }
    }

    @Test("dependency allowlist holds: GRDB only (invariant #2: zero third-party SDKs)")
    func dependencyAllowlist() throws {
        // Arrange
        let resolvedURL = Self.repoRoot.appendingPathComponent("Package.resolved")
        let data = try Data(contentsOf: resolvedURL)
        let resolved = try JSONDecoder().decode(PackageResolved.self, from: data)

        // Act
        let identities = Set(resolved.pins.map(\.identity))

        // Assert
        let allowlist: Set = ["grdb.swift"]
        #expect(
            identities == allowlist,
            "Package.resolved drifted from the allowlist: \(identities.sorted())"
        )
    }

    @Test("no analytics or tracking SDK import anywhere in the tree")
    func noTrackingSDKImports() throws {
        // Belt-and-braces over invariant #2: even a vendored tracker would show
        // up as an import. (Substring match — also catches FirebaseAnalytics etc.)
        let bannedImportSubstrings = [
            "import Firebase", "import Amplitude", "import Mixpanel",
            "import Sentry", "import Crashlytics", "import FacebookCore",
            "import AppsFlyer", "import Adjust",
        ]
        let roots = ["Packages", "App"].map { Self.repoRoot.appendingPathComponent($0) }
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            for file in try Self.swiftFiles(under: root) {
                let source = try String(contentsOf: file, encoding: .utf8)
                for banned in bannedImportSubstrings where source.contains(banned) {
                    Issue.record("tracking SDK import '\(banned)' in \(file.path)")
                }
            }
        }
    }

    // MARK: - Helpers

    static func swiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
    }
}

private struct PackageResolved: Decodable {
    struct Pin: Decodable {
        let identity: String
    }

    let pins: [Pin]
}
