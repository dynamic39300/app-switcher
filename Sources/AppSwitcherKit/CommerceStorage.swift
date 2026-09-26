import Foundation
import CryptoKit
import Security
import AppSwitcherCore

public struct CommercePendingLogin: Codable, Sendable {
    public let verifier: String
    public let state: String
    public let expiresAt: Int64
    public init(verifier: String, state: String, expiresAt: Int64) {
        self.verifier = verifier; self.state = state; self.expiresAt = expiresAt
    }
}

public struct CommerceStoredSession: Codable, Sendable {
    public var tokens: CommerceTokens?
    public var tokenExpiresAt: Int64?
    public var license: String?
    public var entitlement: CommerceEntitlement?
    public var clock: CommerceClock?
    public var pending: CommercePendingLogin?
    public var confirmedAt: Int64?
    public var dismissedState: String?
    public init() {}
}

/// One atomic Keychain item: rotated refresh token and its matching access token cannot diverge.
/// Device-only storage is deliberate; new Macs authorize independently without a device quota.
public final class CommerceSecureStore: @unchecked Sendable {
    private let service: String
    public init(service: String = "com.appswitcher.commerce.v1") { self.service = service }

    public static func serviceName(issuer: String) -> String {
        let digest = SHA256.hash(data: Data(issuer.utf8)).map { String(format: "%02x", $0) }.joined()
        return "com.appswitcher.commerce.v1." + digest
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "current-session",
         kSecAttrSynchronizable as String: false]
    }

    public func read() throws -> CommerceStoredSession {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return CommerceStoredSession() }
        guard status == errSecSuccess, let data = result as? Data,
              let value = try? JSONDecoder().decode(CommerceStoredSession.self, from: data) else {
            throw CommerceFailure.secureStorage
        }
        return value
    }

    public func write(_ value: CommerceStoredSession) throws {
        let data = try JSONEncoder().encode(value)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(insert as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CommerceFailure.secureStorage }
    }

    public func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CommerceFailure.secureStorage }
    }

    public static func randomToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CommerceFailure.secureStorage
        }
        return CommerceEncoding.base64URL(Data(bytes))
    }
}
