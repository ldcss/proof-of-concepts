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
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(cloudKitService: CloudKitServiceProtocol = CloudKitService()) {
        self.cloudKitService = cloudKitService
        checkCloudKitAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Handles successful login from authentication flows
    func loginUser(_ userProfile: UserProfile, family: Family?) {
        currentUser = userProfile
        currentFamily = family
        isLoggedIn = true
        showOnboarding = false
    }
    
    /// Logs out the current user
    func logout() {
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
}
