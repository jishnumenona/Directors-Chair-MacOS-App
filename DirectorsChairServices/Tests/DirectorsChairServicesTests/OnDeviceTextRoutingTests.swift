// DirectorsChairServicesTests/OnDeviceTextRoutingTests.swift
//
// DC-0057: choosing the local model must ROUTE, not decorate. Real MLX
// cannot run under SPM test runners (its metallib only ships in app
// bundles — loading it aborts the process, which is exactly how the
// first cut of this test died), so the routing contract is pinned
// through the injectable engine seam: an .onDevice request reaches the
// engine and never the network; an unready engine's refusal propagates
// honestly instead of silently falling back to a paid server call.

import XCTest
@testable import DirectorsChairServices

final class OnDeviceTextRoutingTests: XCTestCase {

    final class StubEngine: OnDeviceTextResponding, @unchecked Sendable {
        var result: Result<String, Error>
        private(set) var calls: [(prompt: String, maxTokens: Int)] = []
        init(result: Result<String, Error>) { self.result = result }
        func respond(prompt: String, systemPrompt: String?,
                     maxTokens: Int, temperature: Double) async throws -> String {
            calls.append((prompt, maxTokens))
            return try result.get()
        }
    }

    private var savedEngine: (any OnDeviceTextResponding)!

    override func setUp() {
        super.setUp()
        savedEngine = AIServiceClient.onDeviceTextEngine
    }

    override func tearDown() {
        AIServiceClient.onDeviceTextEngine = savedEngine
        super.tearDown()
    }

    func testOnDeviceRequestRoutesToTheEngineNotTheWire() async throws {
        let stub = StubEngine(result: .success("Local words."))
        AIServiceClient.onDeviceTextEngine = stub
        // Unroutable base: any network attempt would fail loudly instead
        // of returning the stub's text.
        let client = AIServiceClient(baseURL: "https://invalid.invalid")

        let response = try await client.generateText(
            TextGenerationRequest(prompt: "Hello", provider: .onDevice,
                                  maxTokens: 321))
        XCTAssertEqual(response.text, "Local words.")
        XCTAssertEqual(response.provider, .onDevice)
        XCTAssertEqual(response.usage.totalTokens, 0, "on-device is unmetered")
        XCTAssertEqual(stub.calls.map(\.maxTokens), [321])
    }

    func testUnreadyEngineRefusalPropagatesInsteadOfFallingBack() async {
        let refusal = InsightEngineError.notReady(
            .needsDownload(expectedBytes: 42))
        AIServiceClient.onDeviceTextEngine = StubEngine(result: .failure(refusal))
        let client = AIServiceClient(baseURL: "https://invalid.invalid")

        do {
            _ = try await client.generateText(
                TextGenerationRequest(prompt: "Hello", provider: .onDevice))
            XCTFail("must refuse, never silently fall back to a server call")
        } catch let error as InsightEngineError {
            XCTAssertEqual(error, .notReady(.needsDownload(expectedBytes: 42)))
        } catch {
            XCTFail("expected the engine's own refusal, got \(error)")
        }
    }

    func testOnDeviceIsNeverAWireValueElsewhere() {
        // The sentinel raw value is "device" — the gateway has no such
        // provider; generateText's early branch keeps it off the wire.
        XCTAssertEqual(AIProvider.onDevice.rawValue, "device")
    }
}
