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
    
    private static let service = "com.yourapp.appleSignIn"
    private static let appleUserIdKey = "appleUserId"
    
    // MARK: - Public Methods
    
    /// Saves the Apple User ID to Keychain
    static func saveAppleUserId(_ userId: String) {
        // First delete any existing entry to avoid duplicates
        deleteAppleUserId()
        
        guard let data = userId.data(using: .utf8) else {
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: appleUserIdKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // If add fails, try to update existing item
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: appleUserIdKey
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
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
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data, let userId = String(data: data, encoding: .utf8) {
            return userId
        } else {
            return nil
        }
    }
    
    /// Deletes the Apple User ID from Keychain
    static func deleteAppleUserId() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: appleUserIdKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
    }
}
