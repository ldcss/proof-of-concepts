//
//  KeychainStore.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import Foundation
import Security

/// Utility for securely storing and retrieving data from the Keychain
final class KeychainStore {
    
    // MARK: - Constants
    
    private static let appleUserIdKey = "com.family.signin.appleUserId"
    private static let service = "com.family.signin.keychain"
    
    // MARK: - Public Methods
    
    /// Saves the Apple User ID to Keychain
    static func saveAppleUserId(_ userId: String) {
        let data = Data(userId.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: appleUserIdKey,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save Apple User ID to Keychain: \(status)")
        }
    }
    
    /// Loads the Apple User ID from Keychain
    static func loadAppleUserId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: appleUserIdKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let userId = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return userId
    }
    
    /// Deletes the Apple User ID from Keychain
    static func deleteAppleUserId() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: appleUserIdKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Failed to delete Apple User ID from Keychain: \(status)")
        }
    }
}