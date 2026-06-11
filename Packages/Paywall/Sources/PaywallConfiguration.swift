/// Selection of the commerce provider — the config gate in front of the only
/// permitted network surface.
///
/// Default is the deterministic mock: tests, previews, and plain dev runs
/// never touch StoreKit. The real adapter activates only when explicitly
/// requested via environment (`SELENE_COMMERCE=storekit`) or launch argument
/// (`-commerce-storekit`); there are no payment credentials to configure —
/// StoreKit authenticates through the App Store / a local .storekit file —
/// so missing configuration simply means the mock, never a crash.
public enum CommerceProviderKind: String, Sendable {
    case mock
    case storeKit = "storekit"
}

public enum PaywallConfiguration {
    public static let environmentKey = "SELENE_COMMERCE"
    public static let launchArgument = "-commerce-storekit"

    public static func providerKind(
        environment: [String: String],
        launchArguments: [String]
    ) -> CommerceProviderKind {
        if launchArguments.contains(launchArgument) {
            return .storeKit
        }
        if environment[environmentKey]?.lowercased() == CommerceProviderKind.storeKit.rawValue {
            return .storeKit
        }
        return .mock
    }

    public static func makeProvider(
        kind: CommerceProviderKind,
        clock: any DayClock,
        initialMockSnapshot: EntitlementSnapshot = .neverOwned
    ) -> any PurchaseProviding {
        switch kind {
        case .mock:
            MockPurchaseProvider(clock: clock, initialSnapshot: initialMockSnapshot)
        case .storeKit:
            StoreKitPurchaseProvider(clock: clock)
        }
    }
}
