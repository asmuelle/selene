import Foundation
import Persistence
import SeleneCore
import SwiftUI

/// Composition root. Builds the encrypted local store and hands the model to the
/// UI. Nothing in this target touches the network (invariant #1) — no networking
/// API of any kind, no analytics, no account (invariants #2 and #6).
@main
struct SeleneApp: App {
    private let model: AppModel

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let store = Self.makeStore(arguments: arguments)
        let model = AppModel(store: store)
        if arguments.contains("-uitest-seed-history") {
            SeedHistory.seedRegularHistory(into: store)
        }
        model.refresh()
        self.model = model
    }

    var body: some Scene {
        WindowGroup {
            TodayView(model: model)
        }
    }

    /// Real runs use the encrypted on-disk store; UI tests run fully in memory so
    /// they leave no health data behind on the simulator.
    private static func makeStore(arguments: [String]) -> any SeleneStoring {
        if arguments.contains("-uitest-inmemory") {
            if let store = try? SeleneDatabase(inMemory: ()) {
                return store
            }
        }
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return try SeleneDatabase(directory: support.appendingPathComponent("Selene", isDirectory: true))
        } catch {
            // Last-resort fallback keeps the app usable for this session; the next
            // launch retries the protected on-disk store.
            guard let memory = try? SeleneDatabase(inMemory: ()) else {
                fatalError("Selene could not open any local store: \(error)")
            }
            return memory
        }
    }
}
