//
//  MyActivitiesViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import Foundation
import Combine
import CloudKit

/// ViewModel for children to view their assigned activities
final class MyActivitiesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var myActivities: [MyActivityProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let cloudKitService: CloudKitServiceProtocol
    let userProfile: UserProfile
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        userProfile: UserProfile,
        cloudKitService: CloudKitServiceProtocol = CloudKitService()
    ) {
        self.userProfile = userProfile
        self.cloudKitService = cloudKitService
        loadMyActivities()
    }
    
    // MARK: - Public Methods
    
    /// Refreshes the user's activities
    func refreshActivities() {
        loadMyActivities()
    }
    
    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func loadMyActivities() {
        isLoading = true
        errorMessage = nil
        
        cloudKitService.fetchActivitiesForUser(userProfile)
            .flatMap { [weak self] activities -> AnyPublisher<[MyActivityProgress], Error> in
                guard let self = self else {
                    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                // For each activity, fetch the user's savings entries to calculate their progress
                let progressPublishers = activities.map { activity in
                    self.cloudKitService.fetchSavingsEntriesForUser(self.userProfile, activity: activity)
                        .map { savingsEntries in
                            MyActivityProgress(
                                activity: activity,
                                mySavingsEntries: savingsEntries,
                                myTotalSaved: savingsEntries.reduce(0) { $0 + $1.amountSaved }
                            )
                        }
                        .eraseToAnyPublisher()
                }
                
                return Publishers.MergeMany(progressPublishers)
                    .collect()
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
                receiveValue: { [weak self] myActivityProgresses in
                    self?.isLoading = false
                    self?.myActivities = myActivityProgresses.sorted { $0.activity.endDate < $1.activity.endDate }
                }
            )
            .store(in: &cancellables)
    }
}

/// Represents an activity with the user's personal progress
struct MyActivityProgress: Identifiable {
    let id: String
    let activity: Activity
    let mySavingsEntries: [SavingsEntry]
    let myTotalSaved: Double
    
    init(activity: Activity, mySavingsEntries: [SavingsEntry], myTotalSaved: Double) {
        self.id = activity.id
        self.activity = activity
        self.mySavingsEntries = mySavingsEntries
        self.myTotalSaved = myTotalSaved
    }
    
    /// User's progress percentage (0.0 to 1.0)
    var myProgressPercentage: Double {
        guard activity.moneyGoal > 0 else { return 0.0 }
        return min(1.0, myTotalSaved / activity.moneyGoal)
    }
    
    /// Formatted progress string for the user
    var myProgressText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        let savedText = formatter.string(from: NSNumber(value: myTotalSaved)) ?? "$0.00"
        let goalText = formatter.string(from: NSNumber(value: activity.moneyGoal)) ?? "$0.00"
        
        return "\(savedText) / \(goalText)"
    }
    
    /// Whether the user has achieved the goal
    var hasCompletedGoal: Bool {
        return myTotalSaved >= activity.moneyGoal
    }
    
    /// Amount remaining to reach the goal
    var amountRemaining: Double {
        return max(0, activity.moneyGoal - myTotalSaved)
    }
}
