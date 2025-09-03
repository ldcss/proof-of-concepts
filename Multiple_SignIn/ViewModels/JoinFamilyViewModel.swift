//
//  JoinFamilyViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import Combine
import CloudKit

/// ViewModel for the Join Family flow with role enforcement
final class JoinFamilyViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var inviteCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    // MARK: - Private Properties
    
    private let authenticationService: AuthenticationServiceProtocol
    private let cloudKitService: CloudKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var foundFamily: Family?
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
    
    /// Validates the invite code and proceeds to authentication if valid
    func validateInviteCode() {
        guard !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter an invite code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        cloudKitService.findFamily(by: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines))
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] family in
                    self?.isLoading = false
                    if let family = family {
                        self?.foundFamily = family
                        self?.signInWithApple()
                    } else {
                        self?.errorMessage = "Invalid invite code. Please check and try again."
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func signInWithApple() {
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
                        self?.handleExistingUser(existingProfile, authResult: result)
                    } else {
                        // New user - join the family as a member
                        self?.createNewMemberUser(result)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleExistingUser(_ userProfile: UserProfile, authResult: AppleSignInResult) {
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
                receiveValue: { [weak self] createdFamily in
                    if createdFamily != nil {
                        // User is already a creator - enforce role exclusivity
                        self?.isLoading = false
                        self?.errorMessage = "You are already a family creator. You cannot join another family as a member."
                    } else if let existingFamilyRef = userProfile.familyReference {
                        // User is already a member - check if it's the same family or different
                        if let foundFamily = self?.foundFamily,
                           existingFamilyRef.recordID == foundFamily.record.recordID {
                            // Same family - log them in
                            self?.loginExistingMember(userProfile, family: foundFamily)
                        } else {
                            // Different family - enforce exclusivity
                            self?.isLoading = false
                            self?.errorMessage = "You are already a member of another family. You cannot join multiple families."
                        }
                    } else {
                        // User exists but has no family - this shouldn't happen, but handle gracefully
                        self?.isLoading = false
                        self?.errorMessage = "Your account is in an inconsistent state. Please contact support."
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func loginExistingMember(_ userProfile: UserProfile, family: Family) {
        // Ensure keychain persistence for family members (same as family creators)
        authenticationService.ensureKeychainPersistence(userProfile.appleUserIdentifier)
        
        isLoading = false
        isAuthenticated = true
        appState?.loginUser(userProfile, family: family)
    }
    
    private func createNewMemberUser(_ authResult: AppleSignInResult) {
        guard let family = foundFamily else {
            errorMessage = "No family found to join"
            isLoading = false
            return
        }
        
        // Create family reference for the user profile
        let familyReference = CKRecord.Reference(record: family.record, action: .deleteSelf)
        
        cloudKitService.createUserProfile(
            name: authResult.fullName,
            email: authResult.email,
            appleUserIdentifier: authResult.userIdentifier,
            familyReference: familyReference
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] userProfile in
                // Ensure keychain persistence for new family members (same as family creators)
                self?.authenticationService.ensureKeychainPersistence(authResult.userIdentifier)
                
                self?.isLoading = false
                self?.isAuthenticated = true
                guard let family = self?.foundFamily else { return }
                self?.appState?.loginUser(userProfile, family: family)
            }
        )
        .store(in: &cancellables)
    }
}
