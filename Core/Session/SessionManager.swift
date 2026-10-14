import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var isLoggedIn = false
    @Published var currentUser: APIClient.Member? = nil
    @Published var isLoading = false
    @Published var isRestoringSession = false
    @Published var errorMessage: String?

    private var sessionInvalidatedObserver: NSObjectProtocol?

    private init() {
        sessionInvalidatedObserver = NotificationCenter.default.addObserver(
            forName: .didInvalidateSession,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                SessionManager.shared.handleInvalidatedSession()
            }
        }
    }

    deinit {
        if let sessionInvalidatedObserver {
            NotificationCenter.default.removeObserver(sessionInvalidatedObserver)
        }
    }

    func restoreSession() async {
        Task { await flushPendingSessionRevocations() }
        isRestoringSession = true
        defer { isRestoringSession = false }

        guard let token = KeychainService.shared.loadToken(), !token.isEmpty else {
            isLoggedIn = false
            currentUser = nil
            return
        }

        APIClient.shared.authToken = token

        do {
            let memberResponse = try await APIClient.shared.fetchCurrentUser()
            currentUser = memberResponse.member
            NavigationRouter.shared.resetToHome()
            isLoggedIn = true
            await registerPushTokenIfAvailable()
        } catch {
            print("❌ Failed to restore session: \(error)")
            // Temporary network/server/Keychain failures must not destroy a renewable session.
            // Definitive rejection is cleared by APIClient after refresh has been attempted.
            APIClient.shared.authToken = nil
            currentUser = nil
            isLoggedIn = false
            errorMessage = KeychainService.shared.loadToken() == nil
                ? "Your session ended. Please sign in again."
                : "Unable to reconnect. Your saved sign-in has been kept; please try again."
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.login(email: email, password: password)

            guard let token = response.token, !token.isEmpty else {
                errorMessage = "Login succeeded, but no auth token was returned."
                currentUser = nil
                isLoggedIn = false
                return
            }

            guard let member = response.member else {
                errorMessage = "Login succeeded, but no member record was returned."
                currentUser = nil
                isLoggedIn = false
                return
            }

            APIClient.shared.authToken = token
            KeychainService.shared.saveToken(token)

            currentUser = member
            NavigationRouter.shared.resetToHome()
            isLoggedIn = true

            print("✅ Login success")
            await registerPushTokenIfAvailable()
        } catch {
            print("❌ Login failed: \(error)")
            errorMessage = error.localizedDescription
            currentUser = nil
            isLoggedIn = false
        }
    }

    func logout() {
        if let credentials = KeychainService.shared.loadSession() {
            var pending = pendingSessionRevocations()
            if !pending.contains(credentials.refreshToken) { pending.append(credentials.refreshToken) }
            if let data = try? JSONEncoder().encode(pending), let text = String(data: data, encoding: .utf8) {
                KeychainService.shared.save(text, for: "mtfd.pendingSessionRevocations")
            }
        }
        NavigationRouter.shared.resetToHome()
        APIClient.shared.authToken = nil
        KeychainService.shared.deleteToken()
        currentUser = nil
        isLoggedIn = false
        errorMessage = nil
        Task { await flushPendingSessionRevocations() }
    }

    private func pendingSessionRevocations() -> [String] {
        guard let text = KeychainService.shared.read(for: "mtfd.pendingSessionRevocations"),
              let data = text.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private func flushPendingSessionRevocations() async {
        for token in pendingSessionRevocations() {
            do {
                try await APIClient.shared.revokeSession(refreshToken: token)
                let remaining = pendingSessionRevocations().filter { $0 != token }
                if let data = try? JSONEncoder().encode(remaining), let text = String(data: data, encoding: .utf8) {
                    KeychainService.shared.save(text, for: "mtfd.pendingSessionRevocations")
                }
            } catch { /* Retain the revocation for the next network opportunity. */ }
        }
    }

    private func handleInvalidatedSession() {
        NavigationRouter.shared.resetToHome()
        APIClient.shared.authToken = nil
        currentUser = nil
        isLoggedIn = false
        errorMessage = "Your session expired. Please sign in again."
    }

    func updateProfile(name: String, email: String, phone: String?) async throws {
        let response = try await APIClient.shared.updateProfile(
            name: name,
            email: email,
            phone: phone
        )

        currentUser = response.member
    }

    func registerPushTokenIfAvailable() async {
        print("📬 registerPushTokenIfAvailable called")

        guard let token = AppDelegate.latestAPNsToken, !token.isEmpty else {
            print("📭 No APNs token yet")
            return
        }

        guard let authToken = APIClient.shared.authToken, !authToken.isEmpty else {
            print("🔒 No auth token")
            return
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        let body: [String: Any] = [
            "deviceToken": token,
            "platform": "IOS",
            "deviceName": UIDevice.current.name,
            "appVersion": appVersion,
            "buildNumber": buildNumber
        ]

        do {
            try await APIClient.shared.registerPushDevice(body: body)
        } catch {
            print("❌ Push registration failed: \(error)")
        }
    }
}
