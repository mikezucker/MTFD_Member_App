import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private init() {}

    // MARK: - Keys
    private let authTokenKey = "mtfd.authToken"

    // MARK: - Generic Save

    func save(_ value: String, for key: String) {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        // Remove existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        if status != errSecSuccess {
            print("❌ Keychain save failed with status: \(status)")
        } else {
            print("🔐 Keychain saved value for key: \(key)")
        }
    }

    // MARK: - Generic Read

    func read(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // MARK: - Generic Delete

    func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            print("❌ Keychain delete failed with status: \(status)")
        } else {
            print("🗑️ Keychain deleted value for key: \(key)")
        }
    }

    // MARK: - Auth Token Helpers (🔥 IMPORTANT)

    func saveToken(_ token: String) {
        save(token, for: authTokenKey)
    }

    func loadToken() -> String? {
        return read(for: authTokenKey)
    }

    func deleteToken() {
        delete(for: authTokenKey)
    }
}
