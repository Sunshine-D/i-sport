import Foundation
import Security

enum KeychainStore {
    private static let service = "LightMeal.PersonalVisionKey"
    static func read() -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "api-key",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ value: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "api-key"]
        let bytes = Data(value.utf8)
        let status: OSStatus
        if value.isEmpty { status = SecItemDelete(query as CFDictionary) }
        else {
            let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
            if update == errSecItemNotFound {
                var add = query; add[kSecValueData as String] = bytes
                add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                add[kSecAttrSynchronizable as String] = false
                status = SecItemAdd(add as CFDictionary, nil)
            } else { status = update }
        }
        guard status == errSecSuccess || (value.isEmpty && status == errSecItemNotFound) else {
            throw NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "密钥保存失败"])
        }
    }
}
