import Foundation
import Paywall
import Persistence
import SeleneCore
import SeleneUI
import SwiftUI

/// Composition root. Builds the encrypted local store, the entitlement store
/// (deterministic mock commerce by default; StoreKit only via the explicit
/// `PaywallConfiguration` gate), and hands the models to the UI. Nothing in
/// this target touches the network (invariant #1) — StoreKit itself stays
/// behind the `Paywall` module boundary.
@main
struct SeleneApp: App {
    private let model: AppModel
    private let entitlements: EntitlementStore
    private let ask = AskSeleneModel()

    init() {
        let processInfo = ProcessInfo.processInfo
        let arguments = processInfo.arguments
        let (store, storageLocation) = Self.makeStore(arguments: arguments)
        let model = AppModel(store: store, storageLocation: storageLocation)
        if arguments.contains("-uitest-seed-history") {
            SeedHistory.seedRegularHistory(into: store)
        }
        model.refresh()
        self.model = model
        entitlements = Self.makeEntitlements(
            arguments: arguments, environment: processInfo.environment
        )
    }

    var body: some Scene {
        WindowGroup {
            TodayView(model: model, entitlements: entitlements, ask: ask)
        }
    }

    // MARK: - Commerce composition

    /// Mock commerce by default; the StoreKit adapter only on explicit opt-in.
    /// UI tests script the starting entitlement via `-uitest-entitlement`.
    private static func makeEntitlements(
        arguments: [String], environment: [String: String]
    ) -> EntitlementStore {
        let clock = SystemDayClock()
        let kind = PaywallConfiguration.providerKind(
            environment: environment, launchArguments: arguments
        )
        let provider = PaywallConfiguration.makeProvider(
            kind: kind,
            clock: clock,
            initialMockSnapshot: scriptedSnapshot(arguments: arguments, today: clock.today)
        )
        return EntitlementStore(provider: provider, clock: clock)
    }

    private static func scriptedSnapshot(
        arguments: [String], today: DayNumber
    ) -> EntitlementSnapshot {
        guard
            let flagIndex = arguments.firstIndex(of: "-uitest-entitlement"),
            arguments.indices.contains(flagIndex + 1)
        else {
            return .neverOwned
        }
        return switch arguments[flagIndex + 1] {
        case "lifetime":
            EntitlementSnapshot(ownership: .lifetime, hasEverOwnedEntitlement: true)
        case "trial":
            EntitlementSnapshot(
                ownership: .annual(
                    isInTrialPeriod: true,
                    expiresOnDay: EntitlementReducer.trialEndDay(startingOn: today)
                ),
                hasEverOwnedEntitlement: true
            )
        case "expired":
            EntitlementSnapshot(ownership: .none, hasEverOwnedEntitlement: true)
        default:
            .neverOwned
        }
    }

    /// Real runs use the encrypted on-disk store; UI tests run fully in memory so
    /// they leave no health data behind on the simulator. The storage location is
    /// surfaced honestly on the privacy-proof screen, so it travels with the store.
    private static func makeStore(
        arguments: [String]
    ) -> (any SeleneStoring, DataInventory.StorageLocation) {
        if arguments.contains("-uitest-inmemory") {
            if let store = try? SeleneDatabase(inMemory: ()) {
                return (store, .inMemoryEphemeral)
            }
        }
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let store = try SeleneDatabase(
                directory: support.appendingPathComponent("Selene", isDirectory: true)
            )
            return (store, .onDeviceEncrypted)
        } catch {
            // Last-resort fallback keeps the app usable for this session; the next
            // launch retries the protected on-disk store.
            guard let memory = try? SeleneDatabase(inMemory: ()) else {
                fatalError("Selene could not open any local store: \(error)")
            }
            return (memory, .inMemoryEphemeral)
        }
    }
}
