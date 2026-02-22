import Foundation
import Security

struct KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.mae.apikey"
    private let account = "userAPIKey"
    
    private init() {}
    
    func saveKey(_ key: String) {
        let currentKey = loadKey()
        
        guard let data = key.data(using: .utf8) else { return }
        
        if currentKey == nil {
            // Add new item
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data
            ]
            SecItemAdd(query as CFDictionary, nil)
        } else {
            // Update existing item
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        }
    }
    
    func loadKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
