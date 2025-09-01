//
//  ProfileViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import Combine
import UIKit
import CloudKit

/// ViewModel for managing user profile
final class ProfileViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userProfile: UserProfile
    @Published var family: Family?
    @Published var profileImage: UIImage?
    @Published var showImagePicker = false
    
    // MARK: - Private Properties
    
    private let cloudKitService: CloudKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        userProfile: UserProfile,
        family: Family?,
        cloudKitService: CloudKitServiceProtocol = CloudKitService()
    ) {
        self.userProfile = userProfile
        self.family = family
        self.cloudKitService = cloudKitService
        loadProfileImage()
    }
    
    // MARK: - Public Methods
    
    /// Updates the profile image
    func updateProfileImage(_ image: UIImage) {
        isLoading = true
        errorMessage = nil
        
        // Convert image to CKAsset
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            isLoading = false
            return
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        
        do {
            try imageData.write(to: tempURL)
            let asset = CKAsset(fileURL: tempURL)
            
            cloudKitService.updateUserProfile(userProfile, profileImage: asset)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                        }
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempURL)
                    },
                    receiveValue: { [weak self] updatedProfile in
                        self?.userProfile = updatedProfile
                        self?.profileImage = image
                    }
                )
                .store(in: &cancellables)
        } catch {
            errorMessage = "Failed to save image: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Shows the image picker
    func presentImagePicker() {
        showImagePicker = true
    }
    
    /// Copies the family invite code to clipboard
    func copyInviteCode() {
        if let inviteCode = family?.inviteCode {
            UIPasteboard.general.string = inviteCode
        }
    }
    
    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func loadProfileImage() {
        guard let profileImageAsset = userProfile.profileImage else { return }
        
        // Load image from CKAsset
        if let imageURL = profileImageAsset.fileURL,
           let imageData = try? Data(contentsOf: imageURL),
           let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.profileImage = image
            }
        }
    }
}
