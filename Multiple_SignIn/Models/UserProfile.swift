//
//  UserProfile.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import CloudKit

/// Represents a User Profile in the CloudKit database
struct UserProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
    let appleUserIdentifier: String
    let profileImage: CKAsset?
    let familyReference: CKRecord.Reference?
    let record: CKRecord
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.name = record["name"] as? String ?? ""
        self.email = record["email"] as? String ?? ""
        self.appleUserIdentifier = record["appleUserIdentifier"] as? String ?? ""
        self.profileImage = record["profileImage"] as? CKAsset
        self.familyReference = record["familyReference"] as? CKRecord.Reference
        self.record = record
    }
    
    /// Creates a new UserProfile record for CloudKit
    static func createRecord(
        name: String,
        email: String,
        appleUserIdentifier: String,
        familyReference: CKRecord.Reference? = nil,
        profileImage: CKAsset? = nil
    ) -> CKRecord {
        let record = CKRecord(recordType: RecordType.userProfile)
        record["name"] = name
        record["email"] = email
        record["appleUserIdentifier"] = appleUserIdentifier
        if let familyReference = familyReference {
            record["familyReference"] = familyReference
        }
        if let profileImage = profileImage {
            record["profileImage"] = profileImage
        }
        return record
    }
}

extension UserProfile {
    enum RecordType {
        static let userProfile = "UserProfile"
    }
    
    enum FieldKey {
        static let name = "name"
        static let email = "email"
        static let appleUserIdentifier = "appleUserIdentifier"
        static let profileImage = "profileImage"
        static let familyReference = "familyReference"
    }
}