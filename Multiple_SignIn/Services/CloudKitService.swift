//
//  CloudKitService.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import CloudKit
import Combine

/// Protocol defining CloudKit operations for dependency injection
protocol CloudKitServiceProtocol {
    func createFamily(with inviteCode: String, creatorUserProfile: UserProfile) -> AnyPublisher<Family, Error>
    func findFamily(by inviteCode: String) -> AnyPublisher<Family?, Error>
    func findFamilyByCreator(appleUserIdentifier: String) -> AnyPublisher<Family?, Error>
    func findUserProfile(by appleUserIdentifier: String) -> AnyPublisher<UserProfile?, Error>
    func createUserProfile(name: String, email: String, appleUserIdentifier: String, familyReference: CKRecord.Reference?) -> AnyPublisher<UserProfile, Error>
    func updateUserProfile(_ userProfile: UserProfile, profileImage: CKAsset?) -> AnyPublisher<UserProfile, Error>
    func checkContainerStatus() -> AnyPublisher<CKAccountStatus, Error>
    func getUserProfileWithFamily(by appleUserIdentifier: String) -> AnyPublisher<(UserProfile, Family)?, Error>
}

/// Service responsible for all CloudKit operations in the Public Database
final class CloudKitService: CloudKitServiceProtocol {
    
    // MARK: - Properties
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    
    // MARK: - Initialization
    
    init(containerIdentifier: String = "iCloud.family.signin") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.publicDatabase = container.publicCloudDatabase
    }
    
    // MARK: - Public Methods
    
    /// Checks the current CloudKit account status
    func checkContainerStatus() -> AnyPublisher<CKAccountStatus, Error> {
        Future<CKAccountStatus, Error> { [weak self] promise in
            self?.container.accountStatus { status, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(status))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Creates a new family with the specified invite code and creator
    func createFamily(with inviteCode: String, creatorUserProfile: UserProfile) -> AnyPublisher<Family, Error> {
        let creatorReference = CKRecord.Reference(record: creatorUserProfile.record, action: .none)
        let familyRecord = Family.createRecord(inviteCode: inviteCode, creatorReference: creatorReference)
        
        return Future<Family, Error> { [weak self] promise in
            self?.publicDatabase.save(familyRecord) { record, error in
                if let error = error {
                    promise(.failure(CloudKitError.failedToCreateFamily(error)))
                } else if let record = record {
                    let family = Family(record: record)
                    promise(.success(family))
                } else {
                    promise(.failure(CloudKitError.unexpectedNilRecord))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Finds a family by invite code
    func findFamily(by inviteCode: String) -> AnyPublisher<Family?, Error> {
        let predicate = NSPredicate(format: "%K == %@", Family.FieldKey.inviteCode, inviteCode)
        let query = CKQuery(recordType: Family.RecordType.family, predicate: predicate)
        
        return Future<Family?, Error> { [weak self] promise in
            self?.publicDatabase.perform(query, inZoneWith: nil) { records, error in
                if let error = error {
                    promise(.failure(CloudKitError.failedToFindFamily(error)))
                } else if let records = records, let record = records.first {
                    let family = Family(record: record)
                    promise(.success(family))
                } else {
                    promise(.success(nil))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Finds a family by creator's Apple User Identifier
    func findFamilyByCreator(appleUserIdentifier: String) -> AnyPublisher<Family?, Error> {
        // First find the user profile
        return findUserProfile(by: appleUserIdentifier)
            .flatMap { [weak self] userProfile -> AnyPublisher<Family?, Error> in
                guard let self = self, let userProfile = userProfile else {
                    return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                // Then find family where this user is the creator
                let creatorReference = CKRecord.Reference(record: userProfile.record, action: .none)
                let predicate = NSPredicate(format: "%K == %@", Family.FieldKey.creator, creatorReference)
                let query = CKQuery(recordType: Family.RecordType.family, predicate: predicate)
                
                return Future<Family?, Error> { promise in
                    self.publicDatabase.perform(query, inZoneWith: nil) { records, error in
                        if let error = error {
                            promise(.failure(CloudKitError.failedToFindFamily(error)))
                        } else if let records = records, let record = records.first {
                            let family = Family(record: record)
                            promise(.success(family))
                        } else {
                            promise(.success(nil))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Creates a new user profile
    func createUserProfile(
        name: String,
        email: String,
        appleUserIdentifier: String,
        familyReference: CKRecord.Reference?
    ) -> AnyPublisher<UserProfile, Error> {
        let userRecord = UserProfile.createRecord(
            name: name,
            email: email,
            appleUserIdentifier: appleUserIdentifier,
            familyReference: familyReference
        )
        
        return Future<UserProfile, Error> { [weak self] promise in
            self?.publicDatabase.save(userRecord) { record, error in
                if let error = error {
                    promise(.failure(CloudKitError.failedToCreateUserProfile(error)))
                } else if let record = record {
                    let userProfile = UserProfile(record: record)
                    promise(.success(userProfile))
                } else {
                    promise(.failure(CloudKitError.unexpectedNilRecord))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Finds a user profile by Apple User Identifier
    func findUserProfile(by appleUserIdentifier: String) -> AnyPublisher<UserProfile?, Error> {
        let predicate = NSPredicate(format: "appleUserIdentifier == %@", appleUserIdentifier)
        let query = CKQuery(recordType: UserProfile.RecordType.userProfile, predicate: predicate)
        
        return Future<UserProfile?, Error> { [weak self] promise in
            self?.publicDatabase.perform(query, inZoneWith: nil) { records, error in
                if let error = error {
                    promise(.failure(CloudKitError.failedToFindUserProfile(error)))
                } else if let records = records, let record = records.first {
                    let userProfile = UserProfile(record: record)
                    promise(.success(userProfile))
                } else {
                    promise(.success(nil))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Updates an existing user profile
    func updateUserProfile(_ userProfile: UserProfile, profileImage: CKAsset?) -> AnyPublisher<UserProfile, Error> {
        var record = userProfile.record
        record["profileImage"] = profileImage
        
        return Future<UserProfile, Error> { [weak self] promise in
            self?.publicDatabase.save(record) { savedRecord, error in
                if let error = error {
                    promise(.failure(CloudKitError.failedToUpdateUserProfile(error)))
                } else if let savedRecord = savedRecord {
                    let updatedUserProfile = UserProfile(record: savedRecord)
                    promise(.success(updatedUserProfile))
                } else {
                    promise(.failure(CloudKitError.unexpectedNilRecord))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Gets a user profile along with the associated family data
    func getUserProfileWithFamily(by appleUserIdentifier: String) -> AnyPublisher<(UserProfile, Family)?, Error> {
        return findUserProfile(by: appleUserIdentifier)
            .flatMap { [weak self] userProfile -> AnyPublisher<(UserProfile, Family)?, Error> in
                guard let self = self, let userProfile = userProfile else {
                    return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                // Check if user has a family reference (member)
                if let familyReference = userProfile.familyReference {
                    return Future<(UserProfile, Family)?, Error> { promise in
                        self.publicDatabase.fetch(withRecordID: familyReference.recordID) { record, error in
                            if let error = error {
                                promise(.failure(CloudKitError.failedToFindFamily(error)))
                            } else if let record = record {
                                let family = Family(record: record)
                                promise(.success((userProfile, family)))
                            } else {
                                promise(.success(nil))
                            }
                        }
                    }
                    .eraseToAnyPublisher()
                } else {
                    // Check if user is a creator
                    return self.findFamilyByCreator(appleUserIdentifier: appleUserIdentifier)
                        .map { family in
                            if let family = family {
                                return (userProfile, family)
                            } else {
                                return nil
                            }
                        }
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - CloudKit Error Types

enum CloudKitError: LocalizedError {
    case failedToCreateFamily(Error)
    case failedToFindFamily(Error)
    case failedToCreateUserProfile(Error)
    case failedToFindUserProfile(Error)
    case failedToUpdateUserProfile(Error)
    case unexpectedNilRecord
    case accountNotAvailable
    case familyNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateFamily(let error):
            return "Failed to create family: \(error.localizedDescription)"
        case .failedToFindFamily(let error):
            return "Failed to find family: \(error.localizedDescription)"
        case .failedToCreateUserProfile(let error):
            return "Failed to create user profile: \(error.localizedDescription)"
        case .failedToFindUserProfile(let error):
            return "Failed to find user profile: \(error.localizedDescription)"
        case .failedToUpdateUserProfile(let error):
            return "Failed to update user profile: \(error.localizedDescription)"
        case .unexpectedNilRecord:
            return "Unexpected nil record returned from CloudKit"
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud."
        case .familyNotFound:
            return "No family found with the provided invite code"
        }
    }
}
