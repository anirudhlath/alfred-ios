// Packages/AlfredKit/Tests/AlfredKitTests/Client/RESTClientTests.swift
import Foundation
import Testing
@testable import AlfredKit

/// Mock URLProtocol for intercepting HTTP requests in tests.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    /// Copies httpBodyStream into httpBody so test handlers can access request.httpBody.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else {
            return request
        }
        var mutable = request
        stream.open()
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 4096)
            if count > 0 { data.append(buffer, count: count) }
        }
        stream.close()
        mutable.httpBody = data
        return mutable
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func makeTestRESTClient() -> RESTClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)
    return RESTClient(
        configuration: ServerConfiguration(host: "192.0.2.1", port: 8081),
        session: session
    )
}

/// Suite wrapper enforces serial execution to avoid races on the shared static requestHandler.
@Suite(.serialized)
struct RESTClientTests {

    @Test func healthCheckReturnsTrue() async {
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/health")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"status": "ok", "service": "web-channel"}"#.data(using: .utf8)!
            return (response, data)
        }

        let client = makeTestRESTClient()
        let result = await client.healthCheck()
        #expect(result == true)
    }

    @Test func healthCheckReturnsFalseOnServerError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let client = makeTestRESTClient()
        let result = await client.healthCheck()
        #expect(result == false)
    }

    @Test func healthCheckReturnsFalseOnNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let client = makeTestRESTClient()
        let result = await client.healthCheck()
        #expect(result == false)
    }

    @Test func getIntegrationsDecodesResponse() async throws {
        let json = """
        [{"name": "weather", "category": "env", "schema": {"fields": {"api_key": {"label": "Key", "type": "password", "required": true}}}, "configured": {"api_key": true}}]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/api/integrations")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let client = makeTestRESTClient()
        let integrations = try await client.getIntegrations()
        #expect(integrations.count == 1)
        #expect(integrations[0].name == "weather")
    }

    @Test func registerDeviceSendsCorrectPayload() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/devices/register")
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
            #expect(body["device_token"] == "token123")
            #expect(body["platform"] == "ios")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"status": "ok"}"#.data(using: .utf8)!)
        }

        let client = makeTestRESTClient()
        try await client.registerDevice(token: "token123", platform: "ios", identity: "sir")
    }

    @Test func saveCredentialsThrows403AsForbidden() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, #"{"detail": "Access restricted"}"#.data(using: .utf8)!)
        }

        let client = makeTestRESTClient()
        do {
            try await client.saveCredentials(integration: "weather", fields: ["key": "val"])
            Issue.record("Expected error")
        } catch let error as AlfredAPIError {
            guard case .forbidden = error else {
                Issue.record("Expected .forbidden, got \(error)")
                return
            }
        }
    }
}
