//
//  CloudKitSchemaValidator.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import Foundation
import CloudKit
import Combine

/// Utility to validate CloudKit schema and help with setup
final class CloudKitSchemaValidator {
    
    private let cloudKitService: CloudKitServiceProtocol
    
    init(cloudKitService: CloudKitServiceProtocol = CloudKitService()) {
        self.cloudKitService = cloudKitService
    }
    
    /// Validates that all required record types exist in CloudKit
    func validateSchema() -> AnyPublisher<SchemaValidationResult, Never> {
        let container = CKContainer(identifier: "iCloud.family.signin")
        let publicDatabase = container.publicCloudDatabase
        
        return Future<SchemaValidationResult, Never> { promise in
            var result = SchemaValidationResult()
            let group = DispatchGroup()
            
            // Test Activity record type
            group.enter()
            let activityQuery = CKQuery(recordType: "Activity", predicate: NSPredicate(value: false))
            publicDatabase.perform(activityQuery, inZoneWith: nil) { _, error in
                if let error = error {
                    result.activityExists = !self.isMissingRecordTypeError(error)
                    result.activityError = error.localizedDescription
                } else {
                    result.activityExists = true
                }
                group.leave()
            }
            
            // Test SavingsEntry record type
            group.enter()
            let savingsQuery = CKQuery(recordType: "SavingsEntry", predicate: NSPredicate(value: false))
            publicDatabase.perform(savingsQuery, inZoneWith: nil) { _, error in
                if let error = error {
                    result.savingsEntryExists = !self.isMissingRecordTypeError(error)
                    result.savingsEntryError = error.localizedDescription
                } else {
                    result.savingsEntryExists = true
                }
                group.leave()
            }
            
            // Test existing record types
            group.enter()
            let familyQuery = CKQuery(recordType: "Family", predicate: NSPredicate(value: false))
            publicDatabase.perform(familyQuery, inZoneWith: nil) { _, error in
                if let error = error {
                    result.familyExists = !self.isMissingRecordTypeError(error)
                } else {
                    result.familyExists = true
                }
                group.leave()
            }
            
            group.enter()
            let userQuery = CKQuery(recordType: "UserProfile", predicate: NSPredicate(value: false))
            publicDatabase.perform(userQuery, inZoneWith: nil) { _, error in
                if let error = error {
                    result.userProfileExists = !self.isMissingRecordTypeError(error)
                } else {
                    result.userProfileExists = true
                }
                group.leave()
            }
            
            group.notify(queue: .main) {
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func isMissingRecordTypeError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.localizedDescription.contains("Did not find record type") ||
               (nsError.domain == CKError.errorDomain && nsError.code == CKError.unknownItem.rawValue)
    }
}

struct SchemaValidationResult {
    var familyExists = false
    var userProfileExists = false
    var activityExists = false
    var savingsEntryExists = false
    var activityError: String?
    var savingsEntryError: String?
    
    var isComplete: Bool {
        return familyExists && userProfileExists && activityExists && savingsEntryExists
    }
    
    var missingRecordTypes: [String] {
        var missing: [String] = []
        if !familyExists { missing.append("Family") }
        if !userProfileExists { missing.append("UserProfile") }
        if !activityExists { missing.append("Activity") }
        if !savingsEntryExists { missing.append("SavingsEntry") }
        return missing
    }
    
    var statusMessage: String {
        if isComplete {
            return "✅ All record types exist in CloudKit"
        } else {
            let missingTypes = missingRecordTypes.joined(separator: ", ")
            return "❌ Missing record types: \(missingTypes)"
        }
    }
}