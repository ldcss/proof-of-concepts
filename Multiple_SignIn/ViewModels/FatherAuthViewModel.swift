//
//  FatherAuthViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import Combine
import CloudKit

/// ViewModel for the Father/Admin authentication flow with role enforcement
final class FatherAuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    // MARK: - Private Properties
    
    private let authenticationService: AuthenticationServiceProtocol
    private let cloudKitService: CloudKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var appState: AppStateViewModel?
    
    // MARK: - Initialization
    
    init(
        authenticationService: AuthenticationServiceProtocol = AuthenticationService(),
        cloudKitService: CloudKitServiceProtocol = CloudKitService()
    ) {
        self.authenticationService = authenticationService
        self.cloudKitService = cloudKitService
    }
    
    // MARK: - Public Methods
    
    /// Sets the app state reference for managing global state
    func setAppState(_ appState: AppStateViewModel) {
        self.appState = appState
    }
    
    /// Initiates the father authentication flow with role enforcement
    func authenticateAsFather() {
        isLoading = true
        errorMessage = nil
        
        authenticationService.signInWithApple()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isLoading = false
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] result in
                    self?.handleAuthentication(result)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func handleAuthentication(_ result: AppleSignInResult) {
        // Check if user already exists to enforce role exclusivity
        cloudKitService.findUserProfile(by: result.userIdentifier)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isLoading = false
                        self?.errorMessage = "Failed to check existing user: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] existingProfile in
                    if let existingProfile = existingProfile {
                        // User exists - check their role and enforce exclusivity
                        self?.handleExistingUser(existingProfile)
                    } else {
                        // New user - create family and profile
                        self?.createNewFatherUser(result)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleExistingUser(_ userProfile: UserProfile) {
        // Check if this user is already a family creator
        cloudKitService.findFamilyByCreator(appleUserIdentifier: userProfile.appleUserIdentifier)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isLoading = false
                        self?.errorMessage = "Failed to check family status: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] family in
                    if let family = family {
                        // User is already a creator - log them in
                        self?.loginExistingCreator(userProfile, family: family)
                    } else if userProfile.familyReference != nil {
                        // User is a family member - enforce role exclusivity
                        self?.isLoading = false
                        self?.errorMessage = "You are already a member of a family. You cannot create a new family."
                    } else {
                        // User exists but has no family - this shouldn't happen, but handle gracefully
                        self?.isLoading = false
                        self?.errorMessage = "Your account is in an inconsistent state. Please contact support."
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func loginExistingCreator(_ userProfile: UserProfile, family: Family) {
        // Ensure keychain persistence for family creators
        authenticationService.ensureKeychainPersistence(userProfile.appleUserIdentifier)
        
        isLoading = false
        isAuthenticated = true
        appState?.loginUser(userProfile, family: family)
    }
    
    private func createNewFatherUser(_ authResult: AppleSignInResult) {
        // Generate unique invite code
        let inviteCode = generateInviteCode()
        
        // Create user profile first
        cloudKitService.createUserProfile(
            name: authResult.fullName,
            email: authResult.email,
            appleUserIdentifier: authResult.userIdentifier,
            familyReference: nil
        )
        .flatMap { [weak self] userProfile -> AnyPublisher<(UserProfile, Family), Error> in
            guard let self = self else {
                return Fail(error: CloudKitError.unexpectedNilRecord).eraseToAnyPublisher()
            }
            
            // Create family with this user as creator
            return self.cloudKitService.createFamily(with: inviteCode, creatorUserProfile: userProfile)
                .map { family in (userProfile, family) }
                .eraseToAnyPublisher()
        }
        .flatMap { [weak self] (userProfile, family) -> AnyPublisher<(UserProfile, Family), Error> in
            guard let self = self else {
                return Fail(error: CloudKitError.unexpectedNilRecord).eraseToAnyPublisher()
            }
            
            // Update user profile with family reference using the service method
            let familyReference = CKRecord.Reference(record: family.record, action: .deleteSelf)
            var updatedRecord = userProfile.record
            updatedRecord["familyReference"] = familyReference
            let updatedUserProfile = UserProfile(record: updatedRecord)
            
            return self.cloudKitService.updateUserProfile(updatedUserProfile, profileImage: userProfile.profileImage)
                .map { finalUserProfile in (finalUserProfile, family) }
                .eraseToAnyPublisher()
        }
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] (userProfile, family) in
                // Ensure keychain persistence for new family creators (same as family members)
                self?.authenticationService.ensureKeychainPersistence(authResult.userIdentifier)
                
                self?.isLoading = false
                self?.isAuthenticated = true
                self?.appState?.loginUser(userProfile, family: family)
            }
        )
        .store(in: &cancellables)
    }
    
    private func generateInviteCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        
        let letterPart = String((0..<3).compactMap { _ in letters.randomElement() })
        let numberPart = String((0..<3).compactMap { _ in numbers.randomElement() })
        
        return "\(letterPart)-\(numberPart)"
    }
}
