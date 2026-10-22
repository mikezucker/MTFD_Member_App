import Foundation

extension Notification.Name {
    static let didInvalidateSession = Notification.Name("test.session.invalidated")
}

@MainActor final class KeychainService {
    static let shared = KeychainService()
    var token: String? = "saved-access"
    func loadToken() -> String? { token }
    func saveToken(_ token: String) { self.token = token }
    func deleteToken() { token = nil }
    struct Credentials { let refreshToken: String }
    func loadSession() -> Credentials? { nil }
    func read(for key: String) -> String? { nil }
    func save(_ value: String, for key: String) {}
}

@MainActor final class NavigationRouter {
    static let shared = NavigationRouter()
    func resetToHome() {}
}
@MainActor enum AppDelegate { static let latestAPNsToken: String? = "test-apns" }
struct UIDevice {
    static let current = UIDevice()
    let name = "Test device"
}

@MainActor final class APIClient {
    static let shared = APIClient()
    struct Member { let name: String }
    struct MemberResponse { let member: Member }
    struct LoginResponse { let token: String?; let member: Member? }
    var authToken: String?
    var fetchCount = 0
    var fetchReply: CheckedContinuation<MemberResponse, Error>?
    var pushReply: CheckedContinuation<Void, Never>?
    func fetchCurrentUser() async throws -> MemberResponse {
        fetchCount += 1
        return try await withCheckedThrowingContinuation { fetchReply = $0 }
    }
    func registerPushDevice(body: [String: Any]) async throws {
        await withCheckedContinuation { pushReply = $0 }
    }
    func login(email: String, password: String) async throws -> LoginResponse {
        LoginResponse(token: "test-token", member: Member(name: "Test"))
    }
    func updateProfile(name: String, email: String, phone: String?) async throws -> MemberResponse {
        MemberResponse(member: Member(name: name))
    }
    func revokeSession(refreshToken: String) async throws {}
}

@main struct SessionRestorationTests {
    @MainActor static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        fatalError("Expected task did not reach its suspension point")
    }

    @MainActor static func main() async {
        let session = SessionManager.shared
        let api = APIClient.shared
        let restoration = Task { await session.restoreSession() }
        await waitUntil { api.fetchReply != nil }
        precondition(session.isRestoringSession && !session.isLoggedIn)
        await session.restoreSession()
        precondition(api.fetchCount == 1)
        print("PASS: duplicate restoration does not send another validation request")
        api.fetchReply?.resume(returning: .init(member: .init(name: "Member")))
        api.fetchReply = nil
        await restoration.value
        await waitUntil { api.pushReply != nil }
        precondition(session.isLoggedIn && !session.isRestoringSession)
        precondition(session.currentUser?.name == "Member")
        api.pushReply?.resume()
        api.pushReply = nil
        print("PASS: dashboard is released while push registration is still pending")

        session.logout()
        KeychainService.shared.token = "saved-access"
        let failedRestoration = Task { await session.restoreSession() }
        await waitUntil { api.fetchReply != nil }
        api.fetchReply?.resume(throwing: URLError(.notConnectedToInternet))
        api.fetchReply = nil
        await failedRestoration.value
        precondition(!session.isLoggedIn && !session.isRestoringSession)
        precondition(session.hasSavedSession && session.errorMessage != nil)
        precondition(api.authToken == nil && session.currentUser == nil)
        print("PASS: offline restoration keeps credentials and enables retry without granting access")

        KeychainService.shared.token = nil
        let previousCount = api.fetchCount
        await session.restoreSession()
        precondition(api.fetchCount == previousCount && !session.isRestoringSession)
        print("PASS: missing credentials return immediately without a validation request")
    }
}
