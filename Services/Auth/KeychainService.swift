import Foundation
import Security
import LocalAuthentication
import CryptoKit

nonisolated final class KeychainService: @unchecked Sendable {
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
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
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
        return loadSession()?.accessToken ?? read(for: authTokenKey)
    }

    func deleteToken() {
        deleteSession()
        delete(for: authTokenKey)
    }
}

// A single atomic Keychain item prevents mismatched access/refresh credentials.
nonisolated struct MobileSessionCredentials: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let sessionId: String
    var refreshRequestId: String?
}

extension KeychainService {
    private nonisolated static let sessionLock = NSLock()
    private nonisolated var renewableKey: String { "mtfd.renewableSession.v1" }

    nonisolated func loadSession() -> MobileSessionCredentials? {
        Self.sessionLock.lock()
        defer { Self.sessionLock.unlock() }
        return readSessionUnlocked()
    }

    private nonisolated func readSessionUnlocked() -> MobileSessionCredentials? {
        guard let value = read(for: renewableKey), let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MobileSessionCredentials.self, from: data)
    }

    private nonisolated func writeSessionUnlocked(_ credentials: MobileSessionCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: renewableKey]
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    nonisolated func saveSession(_ credentials: MobileSessionCredentials) throws {
        Self.sessionLock.lock()
        defer { Self.sessionLock.unlock() }
        try writeSessionUnlocked(credentials)
    }

    nonisolated func prepareSessionRefresh() throws -> MobileSessionCredentials {
        Self.sessionLock.lock()
        defer { Self.sessionLock.unlock() }
        guard var credentials = readSessionUnlocked() else { throw APIClient.APIError.sessionExpired }
        if credentials.refreshRequestId == nil {
            credentials.refreshRequestId = UUID().uuidString
            // Persist retry identity before transmission, including across app termination.
            try writeSessionUnlocked(credentials)
        }
        return credentials
    }

    nonisolated func replaceSession(_ replacement: MobileSessionCredentials, matching original: MobileSessionCredentials) throws {
        Self.sessionLock.lock()
        defer { Self.sessionLock.unlock() }
        guard let current = readSessionUnlocked(), current.refreshToken == original.refreshToken,
              current.refreshRequestId == original.refreshRequestId else { throw CancellationError() }
        try writeSessionUnlocked(replacement)
    }

    nonisolated func deleteSession() {
        Self.sessionLock.lock()
        defer { Self.sessionLock.unlock() }
        delete(for: renewableKey)
    }
}

// This key binds one approved reset to its requesting phone. It is not a trusted login credential.
nonisolated enum PasswordRecoveryDeviceKey {
    private static let tag = Data("mtfd.passwordRecovery.v1".utf8)
    static func remove() {
        SecItemDelete([kSecClass as String:kSecClassKey, kSecAttrApplicationTag as String:tag] as CFDictionary)
        KeychainService.shared.delete(for: "mtfd.pendingPasswordRecovery.v1")
    }
    static func createPublicKey() throws -> String {
        remove()
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                          [.privateKeyUsage, .userPresence], &error) else {
            throw error!.takeRetainedValue() as Error
        }
        let attributes: [String:Any] = [
            kSecAttrKeyType as String:kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String:256,
            kSecAttrTokenID as String:kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String:[kSecAttrIsPermanent as String:true,
                                          kSecAttrApplicationTag as String:tag,
                                          kSecAttrAccessControl as String:access]
        ]
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(key),
              let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error?.takeRetainedValue() as Error? ?? NSError(domain: "MTFDRecovery", code: 1,
                userInfo: [NSLocalizedDescriptionKey:"This device cannot create a secure recovery request. Use a supported iPhone with a device passcode."])
        }
        return data.base64EncodedString()
    }
    static func sign(_ challenge: String, password: String) throws -> String {
        let context = LAContext()
        context.localizedReason = "Verify to finish your approved MTFD password reset."
        defer { context.invalidate() }
        let query: [String:Any] = [kSecClass as String:kSecClassKey,
                                  kSecAttrApplicationTag as String:tag,
                                  kSecReturnRef as String:true,
                                  kSecUseAuthenticationContext as String:context]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let result else { throw NSError(domain:NSOSStatusErrorDomain,code:Int(status)) }
        let key = result as! SecKey
        var error: Unmanaged<CFError>?
        // Bind approval to this exact password without persisting a fast password hash.
        let passwordDigest = SHA256.hash(data:Data(password.utf8)).map { String(format:"%02x",$0) }.joined()
        let message = challenge + "\n" + passwordDigest
        guard let signature = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256,
                                                    Data(message.utf8) as CFData, &error) as Data? else {
            throw error?.takeRetainedValue() as Error? ?? NSError(domain:"MTFDRecovery",code:2)
        }
        return signature.base64EncodedString()
    }
}

nonisolated struct PendingPasswordRecovery: Codable, Sendable {
    let identifier: String
    let requestId: String
    let statusToken: String
    let matchCode: String
    let expiresAt: String
    static func load() -> PendingPasswordRecovery? {
        guard let text = KeychainService.shared.read(for:"mtfd.pendingPasswordRecovery.v1"),
              let data = text.data(using:.utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from:data)
    }
    func save() throws {
        let text = String(data:try JSONEncoder().encode(self),encoding:.utf8)!
        KeychainService.shared.save(text,for:"mtfd.pendingPasswordRecovery.v1")
        guard Self.load()?.requestId == requestId else { throw NSError(domain:"MTFDRecovery",code:3,userInfo:[NSLocalizedDescriptionKey:"Your recovery request could not be saved securely. Please try again."]) }
    }
}
