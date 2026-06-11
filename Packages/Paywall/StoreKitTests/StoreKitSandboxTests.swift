import Paywall
import SeleneCore
import StoreKitTest
import XCTest

/// Sandbox purchase E2E on the simulator (M3 acceptance): the real
/// `StoreKitPurchaseProvider` against the local `Selene.storekit`
/// configuration via StoreKitTest — no App Store, no network beyond the
/// in-process StoreKit test session, no credentials.
///
/// This bundle is xcodebuild-only (it is not part of the SPM test suite) and
/// lives inside `Packages/Paywall/` because the Paywall boundary is the only
/// tree allowed to import StoreKit — the repo guards enforce exactly that.
final class StoreKitSandboxTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "Selene")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session = nil
    }

    func testBothSKUsLoadFromTheLocalConfiguration() async throws {
        let provider = StoreKitPurchaseProvider(clock: SystemDayClock())

        let products = try await provider.availableProducts()

        XCTAssertEqual(Set(products.map(\.id)), Set(ProductID.allCases))
        let annual = try XCTUnwrap(products.first { $0.id == .annual })
        let lifetime = try XCTUnwrap(products.first { $0.id == .lifetime })
        XCTAssertTrue(annual.displayPrice.contains("39.99"), annual.displayPrice)
        XCTAssertTrue(lifetime.displayPrice.contains("89.99"), lifetime.displayPrice)
    }

    func testFirstAnnualPurchaseLandsInTrialEntitlement() async throws {
        let clock = SystemDayClock()
        let provider = StoreKitPurchaseProvider(clock: clock)

        let snapshot = try await provider.purchase(.annual)

        guard case let .annual(isInTrialPeriod, expiresOnDay) = snapshot.ownership else {
            return XCTFail("expected annual ownership, got \(snapshot.ownership)")
        }
        XCTAssertTrue(isInTrialPeriod, "first annual purchase must start the introductory trial")
        XCTAssertTrue(snapshot.hasEverOwnedEntitlement)
        XCTAssertGreaterThan(expiresOnDay, clock.today)
        XCTAssertEqual(
            EntitlementReducer.state(from: snapshot, today: clock.today),
            .trial(endsOn: expiresOnDay)
        )
    }

    func testLifetimePurchaseLandsInLifetimeEntitlement() async throws {
        let clock = SystemDayClock()
        let provider = StoreKitPurchaseProvider(clock: clock)

        let snapshot = try await provider.purchase(.lifetime)

        XCTAssertEqual(snapshot.ownership, .lifetime)
        XCTAssertEqual(
            EntitlementReducer.state(from: snapshot, today: clock.today),
            .active(.lifetime)
        )
    }

    func testCurrentEntitlementsOnACleanSessionIsNeverOwned() async {
        let provider = StoreKitPurchaseProvider(clock: SystemDayClock())

        let snapshot = await provider.currentEntitlements()

        XCTAssertEqual(snapshot.ownership, .none)
        XCTAssertFalse(snapshot.hasEverOwnedEntitlement)
        XCTAssertEqual(
            EntitlementReducer.state(from: snapshot, today: SystemDayClock().today),
            .free
        )
    }
}
