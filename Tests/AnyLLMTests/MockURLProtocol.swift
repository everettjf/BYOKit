import Foundation

/// A `URLProtocol` that serves canned responses for tests. Set `handler` to map
/// each outgoing request to a `(status, data, headers)` stub.
final class MockURLProtocol: URLProtocol {
    struct Stub {
        var status: Int = 200
        var data: Data = Data()
        var headers: [String: String] = ["Content-Type": "application/json"]
    }

    nonisolated(unsafe) static var handler: ((URLRequest) throws -> Stub)?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func reset() {
        handler = nil
        lastRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lastRequest = request
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let stub = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.status,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension Data {
    init(json: String) { self = json.data(using: .utf8)! }
}
