//
//  CreateFamilyViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import Combine
import UIKit

/// ViewModel for the Create Family flow
final class CreateFamilyViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    @Published var createdFamily: Family?
    @Published var generatedInviteCode: String?
    
    // MARK: - Private Properties
    
    private let authenticationService: AuthenticationServiceProtocol
    private let cloudKitService: CloudKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var authenticatedUser: AppleSignInResult?
    
    // MARK: - Initialization
    
    init(
        authenticationService: AuthenticationServiceProtocol = AuthenticationService(),
        cloudKitService: CloudKitServiceProtocol = CloudKitService()
    ) {
        self.authenticationService = authenticationService
        self.cloudKitService = cloudKitService
    }
    
    // MARK: - Public Methods
    
    /// Initiates the Sign in with Apple flow
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        authenticationService.signInWithApple()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] result in
                    self?.authenticatedUser = result
                    self?.isAuthenticated = true
                    self?.createFamily()
                }
            )
            .store(in: &cancellables)
    }
    
    /// Copies the invite code to clipboard
    func copyInviteCode() {
        if let inviteCode = generatedInviteCode {
            UIPasteboard.general.string = inviteCode
        }
    }
    
    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func createFamily() {
        guard let user = authenticatedUser else {
            errorMessage = "No authenticated user available"
            return
        }
        
        isLoading = true
        
        // First create the user profile
        cloudKitService.createUserProfile(
            name: user.fullName,
            email: user.email,
            appleUserIdentifier: user.userIdentifier,
            familyReference: nil
        )
        .flatMap { [weak self] userProfile -> AnyPublisher<(String, Family), Error> in
            guard let self = self else {
                return Fail(error: CloudKitError.unexpectedNilRecord)
                    .eraseToAnyPublisher()
            }
            
            // Generate unique invite code
            let inviteCode = self.generateInviteCode()
            
            // Create family with the user profile as creator
            return self.cloudKitService.createFamily(with: inviteCode, creatorUserProfile: userProfile)
                .map { family in (inviteCode, family) }
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
            receiveValue: { [weak self] (inviteCode, family) in
                self?.generatedInviteCode = inviteCode
                self?.createdFamily = family
                self?.isLoading = false
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
