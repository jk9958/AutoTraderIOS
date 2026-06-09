import Foundation
import Security

/// Minimal Keychain wrapper for storing the X-API-Key.
/// The key is sensitive, so it must never live in UserDefaults.
enum KeychainHelper {
    private static let service = "com.autotrader.ios"
    static let apiKeyAccount = "x-api-key"

    static func set(_ value: String?, account: String) {
        guard let value, !value.isEmpty else {
            delete(account: account)
            return
        }
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Convenience

    static var apiKey: String? {
        get { get(account: apiKeyAccount) }
        set { set(newValue, account: apiKeyAccount) }
    }

    /// Masks a key for display: `••••••••<last4>`.
    static func masked(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "Not set" }
        let last4 = String(key.suffix(4))
        return "••••••••\(last4)"
    }
}
