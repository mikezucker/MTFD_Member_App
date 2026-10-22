import Foundation

enum APIClient {
    enum APIError: Error { case sessionExpired, invalidURL, invalidResponse; case serverError(statusCode: Int, message: String?) }
}
final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()
    private let lock = NSLock()
    private var credentials: MobileSessionCredentials?
    func loadSession() -> MobileSessionCredentials? { lock.lock(); defer { lock.unlock() }; return credentials }
    func save(_ c: MobileSessionCredentials?) { lock.lock(); defer { lock.unlock() }; credentials = c }
    func prepareSessionRefresh() throws -> MobileSessionCredentials {
        lock.lock(); defer { lock.unlock() }
        guard var c = credentials else { throw APIClient.APIError.sessionExpired }
        if c.refreshRequestId == nil { c.refreshRequestId = UUID().uuidString; credentials = c }
        return c
    }
    func replaceSession(_ c: MobileSessionCredentials, matching original: MobileSessionCredentials) throws {
        lock.lock(); defer { lock.unlock() }
        guard credentials?.refreshToken == original.refreshToken, credentials?.refreshRequestId == original.refreshRequestId else { throw CancellationError() }
        credentials = c
    }
}
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static var count = 0
    static var status = 200
    static var networkFailure = false
    static var requestIds: [String] = []
    static var beforeReply: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "mtfd.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.count += 1
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }; body.append(buffer, count: count)
            }
        }
        let payload = try! JSONSerialization.jsonObject(with: body) as! [String: String]
        Self.requestIds.append(payload["requestId"]!)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            Self.beforeReply?()
            if Self.networkFailure { self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
            self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data(#"{"token":"new-access","refreshToken":"new-refresh","sessionId":"session"}"#.utf8))
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
@main struct Tests {
    static func reset() {
        KeychainService.shared.save(MobileSessionCredentials(accessToken: "old-access", refreshToken: "old-refresh", sessionId: "session"))
        StubURLProtocol.count = 0; StubURLProtocol.status = 200; StubURLProtocol.networkFailure = false
        StubURLProtocol.requestIds = []; StubURLProtocol.beforeReply = nil
    }
    static func main() async throws {
        URLProtocol.registerClass(StubURLProtocol.self)
        reset()
        let values = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<12 { group.addTask { try await MobileSessionRenewal.shared.renew(rejectedToken: "old-access", baseURL: "https://mtfd.invalid") } }
            var out: [String] = []; for try await value in group { out.append(value) }; return out
        }
        precondition(values.count == 12 && values.allSatisfy { $0 == "new-access" } && StubURLProtocol.count == 1)
        print("PASS: 12 concurrent callers share one renewal")
        _ = try await MobileSessionRenewal.shared.renew(rejectedToken: "old-access", baseURL: "https://mtfd.invalid")
        precondition(StubURLProtocol.count == 1)
        print("PASS: late rejected requests use the renewed token")
        reset(); StubURLProtocol.networkFailure = true
        do { _ = try await MobileSessionRenewal.shared.renew(rejectedToken: "old-access", baseURL: "https://mtfd.invalid"); fatalError("Expected network error") } catch {}
        precondition(KeychainService.shared.loadSession()?.refreshToken == "old-refresh")
        StubURLProtocol.networkFailure = false
        _ = try await MobileSessionRenewal.shared.renew(rejectedToken: "old-access", baseURL: "https://mtfd.invalid")
        precondition(StubURLProtocol.requestIds[0] == StubURLProtocol.requestIds[1])
        print("PASS: network failure retains credentials and retry identity")
        reset(); StubURLProtocol.beforeReply = { KeychainService.shared.save(nil) }
        do { _ = try await MobileSessionRenewal.shared.renew(rejectedToken: "old-access", baseURL: "https://mtfd.invalid"); fatalError("Expected cancellation") } catch is CancellationError {}
        precondition(KeychainService.shared.loadSession() == nil)
        print("PASS: an in-flight renewal cannot resurrect a logged-out session")
        reset(); StubURLProtocol.status = 503
        do { _ = try await MobileSessionRenewal.shared.renew(rejectedToken: "old-access", baseURL: "https://mtfd.invalid"); fatalError("Expected temporary server error") } catch APIClient.APIError.serverError {}
        precondition(KeychainService.shared.loadSession()?.refreshToken == "old-refresh")
        print("PASS: a temporary server outage preserves the saved session")
        reset(); StubURLProtocol.status = 401
        do { _ = try await MobileSessionRenewal.shared.renew(rejectedToken: "old-access", baseURL: "https://mtfd.invalid"); fatalError("Expected expired session") } catch APIClient.APIError.sessionExpired {}
        print("PASS: definitive server rejection reaches the session layer")
    }
}
