import Foundation
import os

/// One observed attempt to load a network request during a test run.
public struct RecordedEgressAttempt: Hashable, Sendable {
    public let url: String
    public let httpMethod: String

    public init(url: String, httpMethod: String) {
        self.url = url
        self.httpMethod = httpMethod
    }
}

/// Process-wide, lock-protected log of intercepted request attempts.
///
/// Swift Testing runs suites in parallel, so assertions over this log must be
/// scoped: negative tests (zero egress) filter out the explicitly marked
/// positive-control URLs instead of asserting global emptiness.
public enum EgressRecorder {
    private static let state = OSAllocatedUnfairLock(initialState: [RecordedEgressAttempt]())

    public static func record(_ attempt: RecordedEgressAttempt) {
        state.withLock { $0.append(attempt) }
    }

    public static var attempts: [RecordedEgressAttempt] {
        state.withLock { $0 }
    }
}

/// The in-process substitute for a mitmproxy capture (documented in DESIGN.md):
/// a `URLProtocol` that claims every URL-loading request in this process,
/// records it, and fails it before it can reach the network.
///
/// Any test that drives code attempting a request while this is installed gets
/// a recorded attempt and a failed load — making "the core flow performs zero
/// network requests" an executable assertion rather than a promise.
public final class EgressInterceptor: URLProtocol {
    public static let errorDomain = "app.selene.egress-guard"

    override public class func canInit(with _: URLRequest) -> Bool {
        // Claim everything: no request escapes to the real network in tests.
        true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        EgressRecorder.record(RecordedEgressAttempt(
            url: request.url?.absoluteString ?? "<no url>",
            httpMethod: request.httpMethod ?? "GET"
        ))
        client?.urlProtocol(self, didFailWithError: NSError(
            domain: Self.errorDomain,
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Blocked by the Selene egress harness (invariant #1: zero egress).",
            ]
        ))
    }

    override public func stopLoading() {
        // Nothing to cancel: the load fails synchronously in startLoading.
    }
}

/// Idempotent installer for the interceptor.
public enum EgressGuard {
    private static let installed = OSAllocatedUnfairLock(initialState: false)

    /// Registers the interceptor for the process-default URL loading system
    /// (covers the shared session — and the core modules are separately
    /// guaranteed to create no sessions at all by the repo-guard source scan).
    public static func install() {
        installed.withLock { isInstalled in
            guard !isInstalled else {
                return
            }
            URLProtocol.registerClass(EgressInterceptor.self)
            isInstalled = true
        }
    }
}
