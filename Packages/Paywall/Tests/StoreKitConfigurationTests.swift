import Foundation
@testable import Paywall
import Testing

/// Contract test for `App/Selene.storekit`: the local StoreKit configuration
/// must carry exactly the two shipped SKUs with the committed pricing —
/// $39.99/yr behind a 7-day free introductory offer, and an $89.99 lifetime
/// non-consumable. Drift between code, config, and DESIGN.md fails here.
@Suite("StoreKit configuration file")
struct StoreKitConfigurationTests {
    static let configURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Paywall
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("App/Selene.storekit")

    private func loadConfiguration() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.configURL)
        let json = try JSONSerialization.jsonObject(with: data)
        return try #require(json as? [String: Any])
    }

    @Test("the lifetime SKU is an $89.99 non-consumable")
    func lifetimeSKU() throws {
        let config = try loadConfiguration()
        let products = try #require(config["products"] as? [[String: Any]])
        let lifetime = try #require(products.first {
            $0["productID"] as? String == ProductID.lifetime.rawValue
        })

        #expect(lifetime["type"] as? String == "NonConsumable")
        #expect(lifetime["displayPrice"] as? String == "89.99")
    }

    @Test("the annual SKU is a $39.99 yearly subscription with a 7-day free trial")
    func annualSKU() throws {
        let config = try loadConfiguration()
        let groups = try #require(config["subscriptionGroups"] as? [[String: Any]])
        let subscriptions = groups.compactMap { $0["subscriptions"] as? [[String: Any]] }
            .flatMap(\.self)
        let annual = try #require(subscriptions.first {
            $0["productID"] as? String == ProductID.annual.rawValue
        })

        #expect(annual["displayPrice"] as? String == "39.99")
        #expect(annual["recurringSubscriptionPeriod"] as? String == "P1Y")

        let intro = try #require(annual["introductoryOffer"] as? [String: Any])
        #expect(intro["paymentMode"] as? String == "free")
        #expect(intro["subscriptionPeriod"] as? String == "P1W")
    }

    @Test("the config sells exactly the SKUs the code knows — no orphans either way")
    func skuParity() throws {
        let config = try loadConfiguration()
        let products = (config["products"] as? [[String: Any]]) ?? []
        let groups = (config["subscriptionGroups"] as? [[String: Any]]) ?? []
        let subscriptions = groups.compactMap { $0["subscriptions"] as? [[String: Any]] }
            .flatMap(\.self)
        let configuredIDs = Set(
            (products + subscriptions).compactMap { $0["productID"] as? String }
        )

        #expect(configuredIDs == Set(ProductID.allCases.map(\.rawValue)))
    }
}
