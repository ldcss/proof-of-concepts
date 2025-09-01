//
//  TrackActivitiesViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import Foundation
import Combine
import CloudKit

/// ViewModel for tracking all family activities (Father's role)
final class TrackActivitiesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activities: [ActivityProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
        loadActivities()
    }
    
    // MARK: - Public Methods
    
    /// Refreshes the activities list
    func refreshActivities() {
        loadActivities()
    }
    
    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func loadActivities() {
        isLoading = true
        errorMessage = nil
        
        cloudKitService.fetchActivitiesForFamily(family)
            .flatMap { [weak self] activities -> AnyPublisher<[ActivityProgress], Error> in
                guard let self = self else {
                    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                // For each activity, fetch its savings entries to calculate progress
                let progressPublishers = activities.map { activity in
                    self.cloudKitService.fetchSavingsEntriesForActivity(activity)
                        .map { savingsEntries in
                            ActivityProgress(
                                activity: activity,
                                savingsEntries: savingsEntries,
                                totalSaved: savingsEntries.reduce(0) { $0 + $1.amountSaved }
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
                receiveValue: { [weak self] activityProgresses in
                    self?.isLoading = false
                    self?.activities = activityProgresses.sorted { $0.activity.endDate < $1.activity.endDate }
                }
            )
            .store(in: &cancellables)
    }
}

/// Represents an activity with its progress information
struct ActivityProgress: Identifiable {
    let id: String
    let activity: Activity
    let savingsEntries: [SavingsEntry]
    let totalSaved: Double
    
    init(activity: Activity, savingsEntries: [SavingsEntry], totalSaved: Double) {
        self.id = activity.id
        self.activity = activity
        self.savingsEntries = savingsEntries
        self.totalSaved = totalSaved
    }
    
    /// Progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard activity.moneyGoal > 0 else { return 0.0 }
        return min(1.0, totalSaved / activity.moneyGoal)
    }
    
    /// Formatted progress string
    var progressText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        let savedText = formatter.string(from: NSNumber(value: totalSaved)) ?? "$0.00"
        let goalText = formatter.string(from: NSNumber(value: activity.moneyGoal)) ?? "$0.00"
        
        return "\(savedText) / \(goalText)"
    }
    
    /// Whether the goal has been achieved
    var isCompleted: Bool {
        return totalSaved >= activity.moneyGoal
    }
}