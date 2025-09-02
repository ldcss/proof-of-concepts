//
//  AppStateViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import Combine
import AuthenticationServices

/// ViewModel responsible for managing app state and user sessions
final class AppStateViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var currentUser: UserProfile?
    @Published var currentFamily: Family?
    @Published var isLoggedIn = false
    @Published var showOnboarding = false
    
    // MARK: - Private Properties
    
    private let cloudKitService: CloudKitServiceProtocol
    private let authenticationService: AuthenticationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        cloudKitService: CloudKitServiceProtocol = CloudKitService(),
        authenticationService: AuthenticationServiceProtocol = AuthenticationService()
    ) {
        self.cloudKitService = cloudKitService
        self.authenticationService = authenticationService
        // Remove automatic CloudKit check - session restoration will handle this
    }
    
    // MARK: - Public Methods
    
    /// Attempts to restore session on app launch
    func restoreSessionOnLaunch() {
        isLoading = true
        errorMessage = nil
        
        // First check CloudKit availability
        cloudKitService.checkContainerStatus()
            .flatMap { [weak self] status -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Fail(error: AppStateError.unexpectedError).eraseToAnyPublisher()
                }
                
                switch status {
                case .available:
                    // CloudKit is ready, try to restore Apple session
                    return self.authenticationService.restoreAppleSession()
                case .noAccount:
                    return Fail(error: AppStateError.iCloudNotAvailable("Please sign in to iCloud to use this app.")).eraseToAnyPublisher()
                case .restricted:
                    return Fail(error: AppStateError.iCloudNotAvailable("iCloud access is restricted.")).eraseToAnyPublisher()
                case .couldNotDetermine, .temporarilyUnavailable:
                    return Fail(error: AppStateError.iCloudNotAvailable("Could not access iCloud. Please try again.")).eraseToAnyPublisher()
                @unknown default:
                    return Fail(error: AppStateError.iCloudNotAvailable("Unknown iCloud status.")).eraseToAnyPublisher()
                }
            }
            .flatMap { [weak self] userIdentifier -> AnyPublisher<(UserProfile, Family)?, Error> in
                guard let self = self else {
                    return Fail(error: AppStateError.unexpectedError).eraseToAnyPublisher()
                }
                
                // Fetch user profile and family data
                return self.cloudKitService.getUserProfileWithFamily(by: userIdentifier)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        // Session restoration failed, show onboarding
                        self?.showOnboarding = true
                        
                        // Only show error message for non-authentication related errors
                        if !(self?.isAuthenticationError(error) ?? true) {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] userProfileAndFamily in
                    self?.isLoading = false
                    
                    if let (userProfile, family) = userProfileAndFamily {
                        // Successfully restored session
                        self?.loginUser(userProfile, family: family)
                    } else {
                        // No existing user/family found, show onboarding
                        self?.showOnboarding = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Handles successful login from authentication flows
    func loginUser(_ userProfile: UserProfile, family: Family?) {
        currentUser = userProfile
        currentFamily = family
        isLoggedIn = true
        showOnboarding = false
    }
    
    /// Logs out the current user
    func logout() {
        // Clear stored credentials
        KeychainStore.deleteAppleUserId()
        
        // Reset app state
        currentUser = nil
        currentFamily = nil
        isLoggedIn = false
        showOnboarding = true
    }
    
    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func checkCloudKitAvailability() {
        isLoading = true
        
        cloudKitService.checkContainerStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        self?.showOnboarding = true
                    }
                },
                receiveValue: { [weak self] status in
                    self?.isLoading = false
                    switch status {
                    case .available:
                        // CloudKit is ready, show onboarding
                        self?.showOnboarding = true
                    case .noAccount:
                        self?.errorMessage = "Please sign in to iCloud to use this app."
                        self?.showOnboarding = true
                    case .restricted:
                        self?.errorMessage = "iCloud access is restricted."
                        self?.showOnboarding = true
                    case .couldNotDetermine, .temporarilyUnavailable:
                        self?.errorMessage = "Could not access iCloud. Please try again."
                        self?.showOnboarding = true
                    @unknown default:
                        self?.errorMessage = "Unknown iCloud status."
                        self?.showOnboarding = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func isAuthenticationError(_ error: Error) -> Bool {
        return error is AuthenticationError
    }
}

// MARK: - App State Errors

enum AppStateError: LocalizedError {
    case iCloudNotAvailable(String)
    case unexpectedError
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable(let message):
            return message
        case .unexpectedError:
            return "An unexpected error occurred."
        }
    }
}
