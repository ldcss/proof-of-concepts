//
//  SavingsEntry.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import Foundation
import CloudKit

/// Represents a savings entry logged by a child for an activity
struct SavingsEntry: Identifiable, Equatable {
    let id: String
    let amountSaved: Double
    let dateLogged: Date
    let notes: String
    let activityReference: CKRecord.Reference
    let userReference: CKRecord.Reference
    let record: CKRecord
    
    init(record: CKRecord) {
        self.id = record.recordID.recordName
        self.amountSaved = record["amountSaved"] as? Double ?? 0.0
        self.dateLogged = record["dateLogged"] as? Date ?? Date()
        self.notes = record["notes"] as? String ?? ""
        self.activityReference = record["activityReference"] as! CKRecord.Reference
        self.userReference = record["userReference"] as! CKRecord.Reference
        self.record = record
    }
    
    /// Creates a new SavingsEntry record for CloudKit
    static func createRecord(
        amountSaved: Double,
        dateLogged: Date,
        notes: String,
        activityReference: CKRecord.Reference,
        userReference: CKRecord.Reference
    ) -> CKRecord {
        let record = CKRecord(recordType: RecordType.savingsEntry)
        record["amountSaved"] = amountSaved
        record["dateLogged"] = dateLogged
        record["notes"] = notes
        record["activityReference"] = activityReference
        record["userReference"] = userReference
        return record
    }
    
    /// Formatted amount string for display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // You can make this configurable
        return formatter.string(from: NSNumber(value: amountSaved)) ?? "$0.00"
    }
    
    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dateLogged)
    }
}

extension SavingsEntry {
    enum RecordType {
        static let savingsEntry = "SavingsEntry"
    }
    
    enum FieldKey {
        static let amountSaved = "amountSaved"
        static let dateLogged = "dateLogged"
        static let notes = "notes"
        static let activityReference = "activityReference"
        static let userReference = "userReference"
    }
}