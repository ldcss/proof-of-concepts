//
//  Activity.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import Foundation
import CloudKit

/// Represents an Activity (savings goal) in the CloudKit database
struct Activity: Identifiable, Equatable {
    let id: String
    let title: String
    let moneyGoal: Double
    let endDate: Date
    let picture: CKAsset?
    let familyReference: CKRecord.Reference
    let assignedTo: [CKRecord.Reference]
    let record: CKRecord
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.title = record["title"] as? String ?? ""
        self.moneyGoal = record["moneyGoal"] as? Double ?? 0.0
        self.endDate = record["endDate"] as? Date ?? Date()
        self.picture = record["picture"] as? CKAsset
        self.familyReference = record["familyReference"] as! CKRecord.Reference
        self.assignedTo = record["assignedTo"] as? [CKRecord.Reference] ?? []
        self.record = record
    }
    
    /// Creates a new Activity record for CloudKit
    static func createRecord(
        title: String,
        moneyGoal: Double,
        endDate: Date,
        picture: CKAsset?,
        familyReference: CKRecord.Reference,
        assignedTo: [CKRecord.Reference]
    ) -> CKRecord {
        let record = CKRecord(recordType: RecordType.activity)
        record["title"] = title
        record["moneyGoal"] = moneyGoal
        record["endDate"] = endDate
        record["familyReference"] = familyReference
        record["assignedTo"] = assignedTo
        if let picture = picture {
            record["picture"] = picture
        }
        return record
    }
    
    /// Checks if the activity is assigned to a specific user
    func isAssignedTo(_ userProfile: UserProfile) -> Bool {
        return assignedTo.contains { $0.recordID == userProfile.record.recordID }
    }
    
    /// Calculates days remaining until end date
    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: endDate)
        return max(0, components.day ?? 0)
    }
    
    /// Checks if the activity has expired
    var isExpired: Bool {
        return Date() > endDate
    }
}

extension Activity {
    enum RecordType {
        static let activity = "Activity"
    }
    
    enum FieldKey {
        static let title = "title"
        static let moneyGoal = "moneyGoal"
        static let endDate = "endDate"
        static let picture = "picture"
        static let familyReference = "familyReference"
        static let assignedTo = "assignedTo"
    }
}