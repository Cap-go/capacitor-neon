import Foundation
import Security

/// Stores the Neon Auth session cookie in the iOS Keychain.
final class KeychainTokenStore: NeonTokenStore {
    private let service: String

    init(service: String = "CapacitorNeon") {
        self.service = service
    }

    func read(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func write(_ key: String, _ value: String?) {
        let query = baseQuery(key)
        SecItemDelete(query as CFDictionary)
        guard let value = value, let data = value.data(using: .utf8) else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
