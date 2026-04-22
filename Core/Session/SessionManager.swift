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

    private init() {}

    func restoreSession() async {
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
            isLoggedIn = true
            await registerPushTokenIfAvailable()
        } catch {
            print("❌ Failed to restore session: \(error)")
            APIClient.shared.authToken = nil
            KeychainService.shared.deleteToken()
            currentUser = nil
            isLoggedIn = false
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
        APIClient.shared.authToken = nil
        KeychainService.shared.deleteToken()
        currentUser = nil
        isLoggedIn = false
        errorMessage = nil
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

        guard let url = URL(string: "https://new-mtfd-site.vercel.app/api/mobile/push/register") else {
            print("❌ Invalid push registration URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

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
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                print("✅ Push register status: \(http.statusCode)")
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Push response: \(responseString)")
            }
        } catch {
            print("❌ Push registration failed: \(error)")
        }
    }
}
