@testable import Paywall
import SeleneCore
import Testing

@Suite("Feature gate")
struct FeatureGateTests {
    private let gate = FeatureGate()
    private let today = DayNumber(20614)

    private var allEntitlementStates: [EntitlementState] {
        [
            .free,
            .trial(endsOn: today.advanced(by: 6)),
            .trial(endsOn: today.advanced(by: -1)),
            .active(.annual),
            .active(.lifetime),
            .expired,
        ]
    }

    @Test("free-forever features are unlocked in every entitlement state (invariant #7)")
    func freeFeaturesAlwaysUnlocked() {
        // Arrange
        let freeFeatures = Feature.allCases.filter(\.isFreeForever)

        // Act & Assert: no entitlement state may ever gate logging/history/export/delete.
        for state in allEntitlementStates {
            for feature in freeFeatures {
                #expect(
                    gate.isUnlocked(feature, entitlement: state, today: today),
                    "\(feature) must be free in state \(state)"
                )
            }
        }
    }

    @Test("AI features are locked for free and expired users")
    func aiFeaturesLockedWithoutEntitlement() {
        let aiFeatures = Feature.allCases.filter { !$0.isFreeForever }
        for state in [EntitlementState.free, .expired] {
            for feature in aiFeatures {
                #expect(!gate.isUnlocked(feature, entitlement: state, today: today))
            }
        }
    }

    @Test("an active trial unlocks the AI layer through its last day")
    func trialUnlocksUntilEnd() {
        // Arrange
        let trial = EntitlementState.trial(endsOn: today.advanced(by: 6))

        // Act & Assert
        #expect(gate.isUnlocked(.insightNarration, entitlement: trial, today: today))
        #expect(gate.isUnlocked(
            .insightNarration, entitlement: trial, today: today.advanced(by: 6)
        ))
        #expect(!gate.isUnlocked(
            .insightNarration, entitlement: trial, today: today.advanced(by: 7)
        ))
    }

    @Test("annual and lifetime purchases unlock every feature")
    func purchasesUnlockEverything() {
        for product in ProductID.allCases {
            for feature in Feature.allCases {
                #expect(gate.isUnlocked(
                    feature, entitlement: .active(product), today: today
                ))
            }
        }
    }

    @Test("entitlement state round-trips through Codable for local persistence")
    func entitlementCodableRoundTrip() throws {
        // Arrange
        let states: [EntitlementState] = [.free, .trial(endsOn: today), .active(.lifetime)]

        // Act & Assert
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(EntitlementState.self, from: data)
            #expect(decoded == state)
        }
    }
}

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
