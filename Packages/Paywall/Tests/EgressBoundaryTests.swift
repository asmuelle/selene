import EgressGuardKit
import Foundation
import Testing

/// Positive control for the egress harness, placed deliberately inside the
/// Paywall test target: `Paywall/` is the single module permitted to touch
/// networking APIs (invariant #1), so the one test that *attempts* a request —
/// to prove the harness catches and blocks it — lives on this side of the
/// boundary. The request never reaches the network: the interceptor claims it
/// and fails the load in-process.
@Suite("Egress harness — paywall boundary positive control")
struct EgressBoundaryTests {
    /// Unique marker so the core-flow no-egress tests can exclude this
    /// deliberate attempt when suites run in parallel.
    static let controlURL = "https://egress-positive-control.invalid/selene"

    @Test("a real request attempt is recorded and blocked before reaching the network")
    func harnessCatchesAndBlocksAttempts() async throws {
        // Arrange
        EgressGuard.install()
        let url = try #require(URL(string: Self.controlURL))

        // Act: an actual URLSession load — the kind of call that must never
        // exist outside this module. The harness must fail it in-process.
        let result: Result<Data, any Error> = await withCheckedContinuation { continuation in
            URLSession.shared.dataTask(with: url) { data, _, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(data ?? Data()))
                }
            }.resume()
        }

        // Assert: blocked with the harness error, never a successful load.
        switch result {
        case .success:
            Issue.record("egress harness failed to block a live request attempt")
        case let .failure(error):
            let nsError = error as NSError
            #expect(nsError.domain == EgressInterceptor.errorDomain)
        }

        // And the attempt is on the record, URL and method intact.
        let recorded = EgressRecorder.attempts.filter { $0.url == Self.controlURL }
        #expect(!recorded.isEmpty, "harness did not record the attempted request")
        #expect(recorded.allSatisfy { $0.httpMethod == "GET" })
    }
}
