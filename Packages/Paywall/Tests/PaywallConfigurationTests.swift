@testable import Paywall
import SeleneCore
import Testing

/// The config gate in front of the only permitted network surface: StoreKit
/// activates only on explicit opt-in; everything else gets the deterministic
/// mock — no credentials, no crash, no accidental store traffic.
@Suite("Paywall configuration gating")
struct PaywallConfigurationTests {
    @Test("default is the mock provider — tests and dev runs never touch StoreKit")
    func defaultsToMock() {
        #expect(
            PaywallConfiguration.providerKind(environment: [:], launchArguments: []) == .mock
        )
    }

    @Test("unrelated environment values still resolve to the mock")
    func unrelatedEnvIgnored() {
        let kind = PaywallConfiguration.providerKind(
            environment: ["SELENE_COMMERCE": "production-please", "PATH": "/usr/bin"],
            launchArguments: ["-uitest-inmemory"]
        )
        #expect(kind == .mock)
    }

    @Test("SELENE_COMMERCE=storekit opts into the real adapter")
    func envOptIn() {
        let kind = PaywallConfiguration.providerKind(
            environment: ["SELENE_COMMERCE": "storekit"], launchArguments: []
        )
        #expect(kind == .storeKit)
    }

    @Test("the -commerce-storekit launch argument opts into the real adapter")
    func launchArgumentOptIn() {
        let kind = PaywallConfiguration.providerKind(
            environment: [:], launchArguments: ["-commerce-storekit"]
        )
        #expect(kind == .storeKit)
    }

    @Test("the factory builds the matching provider type")
    func factoryBuildsMatchingProvider() {
        let clock = FixedDayClock(today: DayNumber(20614))

        let mock = PaywallConfiguration.makeProvider(kind: .mock, clock: clock)
        let real = PaywallConfiguration.makeProvider(kind: .storeKit, clock: clock)

        #expect(mock is MockPurchaseProvider)
        #expect(real is StoreKitPurchaseProvider)
    }
}
