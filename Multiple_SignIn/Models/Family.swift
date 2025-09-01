//
//  Family.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import CloudKit

/// Represents a Family group in the CloudKit database
struct Family: Identifiable, Equatable {
    let id: String
    let inviteCode: String
    let creatorReference: CKRecord.Reference?
    let record: CKRecord
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.inviteCode = record["inviteCode"] as? String ?? ""
        self.creatorReference = record["creator"] as? CKRecord.Reference
        self.record = record
    }
    
    /// Creates a new Family record for CloudKit
    static func createRecord(inviteCode: String, creatorReference: CKRecord.Reference) -> CKRecord {
        let record = CKRecord(recordType: RecordType.family)
        record["inviteCode"] = inviteCode
        record["creator"] = creatorReference
        return record
    }
}

extension Family {
    enum RecordType {
        static let family = "Family"
    }
    
    enum FieldKey {
        static let inviteCode = "inviteCode"
        static let creator = "creator"
    }
}