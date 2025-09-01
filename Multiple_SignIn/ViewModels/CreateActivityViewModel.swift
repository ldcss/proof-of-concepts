//
//  CreateActivityViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import Foundation
import Combine
import CloudKit
import UIKit

/// ViewModel for creating new activities (Father's role)
final class CreateActivityViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var title = ""
    @Published var moneyGoal = ""
    @Published var endDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @Published var selectedImage: UIImage?
    @Published var familyMembers: [UserProfile] = []
    @Published var selectedMembers: Set<UserProfile> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activityCreated = false
    
    // MARK: - Private Properties
    
    private let cloudKitService: CloudKitServiceProtocol
    private let family: Family
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        family: Family,
        cloudKitService: CloudKitServiceProtocol = CloudKitService()
    ) {
        self.family = family
        self.cloudKitService = cloudKitService
        loadFamilyMembers()
    }
    
    // MARK: - Public Methods
    
    /// Toggles selection of a family member
    func toggleMemberSelection(_ member: UserProfile) {
        if selectedMembers.contains(member) {
            selectedMembers.remove(member)
        } else {
            selectedMembers.insert(member)
        }
    }
    
    /// Validates the form and creates the activity
    func createActivity() {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Convert money goal to Double
        let goalAmount = Double(moneyGoal) ?? 0.0
        
        // Convert image to CKAsset if provided
        var pictureAsset: CKAsset?
        if let image = selectedImage {
            pictureAsset = createImageAsset(from: image)
        }
        
        // Create family reference
        let familyReference = CKRecord.Reference(record: family.record, action: .deleteSelf)
        
        // Create member references
        let memberReferences = selectedMembers.map { member in
            CKRecord.Reference(record: member.record, action: .none)
        }
        
        cloudKitService.createActivity(
            title: title,
            moneyGoal: goalAmount,
            endDate: endDate,
            picture: pictureAsset,
            familyReference: familyReference,
            assignedTo: memberReferences
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] _ in
                self?.isLoading = false
                self?.activityCreated = true
            }
        )
        .store(in: &cancellables)
    }
    
    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func loadFamilyMembers() {
        isLoading = true
        
        cloudKitService.fetchFamilyMembers(family)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] members in
                    self?.isLoading = false
                    self?.familyMembers = members
                }
            )
            .store(in: &cancellables)
    }
    
    private func validateForm() -> Bool {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter an activity title"
            return false
        }
        
        if moneyGoal.isEmpty || Double(moneyGoal) == nil || Double(moneyGoal)! <= 0 {
            errorMessage = "Please enter a valid money goal"
            return false
        }
        
        if endDate <= Date() {
            errorMessage = "Please select a future end date"
            return false
        }
        
        if selectedMembers.isEmpty {
            errorMessage = "Please select at least one family member to assign this activity to"
            return false
        }
        
        return true
    }
    
    private func createImageAsset(from image: UIImage) -> CKAsset? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        do {
            try imageData.write(to: tempURL)
            return CKAsset(fileURL: tempURL)
        } catch {
            print("Failed to create image asset: \(error)")
            return nil
        }
    }
}

extension UserProfile: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}