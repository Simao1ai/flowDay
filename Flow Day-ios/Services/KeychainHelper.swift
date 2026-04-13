// KeychainHelper.swift
// FlowDay

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.flowday.app"

    private init() {}

    // MARK: - Data Methods

    func save(_ data: Data, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            debugPrint("Keychain save error for key '\(key)': \(status)")
        }
    }

    func read(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        }

        if status != errSecItemNotFound {
            debugPrint("Keychain read error for key '\(key)': \(status)")
        }

        return nil
    }

    func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            debugPrint("Keychain delete error for key '\(key)': \(status)")
        }
    }

    // MARK: - String Methods

    func saveString(_ string: String, for key: String) {
        guard let data = string.data(using: .utf8) else {
            debugPrint("Failed to convert string to data for key '\(key)'")
            return
        }
        save(data, for: key)
    }

    func readString(for key: String) -> String? {
        guard let data = read(for: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
