//
//  OnboardingViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for the main onboarding screen
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var navigationPath: NavigationPath = .init()
    
    // MARK: - Private Properties
    
    private let cloudKitService: CloudKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(cloudKitService: CloudKitServiceProtocol = CloudKitService()) {
        self.cloudKitService = cloudKitService
        checkCloudKitAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Navigates to the Father authentication flow
    func navigateToFatherAuth() {
        navigationPath.append(FlowDestination.fatherAuth)
    }
    
    /// Navigates to the Join Family flow
    func navigateToJoinFamily() {
        navigationPath.append(FlowDestination.joinFamily)
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
                    }
                },
                receiveValue: { [weak self] status in
                    self?.isLoading = false
                    switch status {
                    case .available:
                        break // CloudKit is ready
                    case .noAccount:
                        self?.errorMessage = "Please sign in to iCloud to use this app."
                    case .restricted:
                        self?.errorMessage = "iCloud access is restricted."
                    case .couldNotDetermine:
                        self?.errorMessage = "Could not determine iCloud status."
                    case .temporarilyUnavailable:
                        self?.errorMessage = "Could not get the resource."
                    @unknown default:
                        self?.errorMessage = "Unknown iCloud status."
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Navigation Destinations

enum FlowDestination: Hashable {
    case fatherAuth
    case joinFamily
}
