//
//  ActivityDetailViewModel.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import Foundation
import Combine
import CloudKit

/// ViewModel for viewing activity details and logging savings
final class ActivityDetailViewModel: ObservableObject {
  
  // MARK: - Published Properties
  
  @Published var activity: Activity
  @Published var mySavingsEntries: [SavingsEntry] = []
  @Published var myTotalSaved: Double = 0.0
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var showLogSavingsSheet = false
  
  // MARK: - Logging Properties
  
  @Published var amountToLog = ""
  @Published var notesToLog = ""
  @Published var isLoggingSavings = false
  
  // MARK: - Private Properties
  
  private let cloudKitService: CloudKitServiceProtocol
  private let userProfile: UserProfile
  private var cancellables = Set<AnyCancellable>()
  
  // MARK: - Initialization
  
  init(
    activity: Activity,
    userProfile: UserProfile,
    cloudKitService: CloudKitServiceProtocol = CloudKitService()
  ) {
    self.activity = activity
    self.userProfile = userProfile
    self.cloudKitService = cloudKitService
    loadMySavingsEntries()
  }
  
  // MARK: - Public Methods
  
  /// Shows the log savings sheet
  func showLogSavings() {
    showLogSavingsSheet = true
  }
  
  /// Dismisses the log savings sheet and clears form
  func dismissLogSavings() {
    showLogSavingsSheet = false
    clearLogSavingsForm()
  }
  
  /// Logs a new savings entry
  func logSavings() {
    guard validateLogSavingsForm() else { return }
    
    isLoggingSavings = true
    errorMessage = nil
    
    let amount = Double(amountToLog) ?? 0.0
    let activityReference = CKRecord.Reference(record: activity.record, action: .deleteSelf)
    let userReference = CKRecord.Reference(record: userProfile.record, action: .none)
    
    cloudKitService.createSavingsEntry(
      amountSaved: amount,
      dateLogged: Date(),
      notes: notesToLog.trimmingCharacters(in: .whitespacesAndNewlines),
      activityReference: activityReference,
      userReference: userReference
    )
    .receive(on: DispatchQueue.main)
    .sink(
      receiveCompletion: { [weak self] completion in
        self?.isLoggingSavings = false
        if case .failure(let error) = completion {
          self?.errorMessage = error.localizedDescription
        }
      },
      receiveValue: { [weak self] newEntry in
        self?.isLoggingSavings = false
        self?.mySavingsEntries.append(newEntry)
        self?.mySavingsEntries.sort { $0.dateLogged > $1.dateLogged }
        self?.updateTotalSaved()
        self?.dismissLogSavings()
      }
    )
    .store(in: &cancellables)
  }
  
  /// Refreshes the savings entries
  func refreshSavingsEntries() {
    loadMySavingsEntries()
  }
  
  /// Clears any error messages
  func clearError() {
    errorMessage = nil
  }
  
  // MARK: - Computed Properties
  
  /// Progress percentage (0.0 to 1.0)
  var progressPercentage: Double {
    guard activity.moneyGoal > 0 else { return 0.0 }
    return min(1.0, myTotalSaved / activity.moneyGoal)
  }
  
  /// Formatted progress string
  var progressText: String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    
    let savedText = formatter.string(from: NSNumber(value: myTotalSaved)) ?? "$0.00"
    let goalText = formatter.string(from: NSNumber(value: activity.moneyGoal)) ?? "$0.00"
    
    return "\(savedText) / \(goalText)"
  }
  
  /// Whether the goal has been achieved
  var hasCompletedGoal: Bool {
    return myTotalSaved >= activity.moneyGoal
  }
  
  /// Amount remaining to reach the goal
  var amountRemaining: Double {
    return max(0, activity.moneyGoal - myTotalSaved)
  }
  
  // MARK: - Private Methods
  
  private func loadMySavingsEntries() {
    isLoading = true
    errorMessage = nil
    
    cloudKitService.fetchSavingsEntriesForUser(userProfile, activity: activity)
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { [weak self] completion in
          self?.isLoading = false
          if case .failure(let error) = completion {
            self?.errorMessage = error.localizedDescription
          }
        },
        receiveValue: { [weak self] savingsEntries in
          self?.isLoading = false
          self?.mySavingsEntries = savingsEntries.sorted { $0.dateLogged > $1.dateLogged }
          self?.updateTotalSaved()
        }
      )
      .store(in: &cancellables)
  }
  
  private func updateTotalSaved() {
    myTotalSaved = mySavingsEntries.reduce(0) { $0 + $1.amountSaved }
  }
  
  private func validateLogSavingsForm() -> Bool {
    if amountToLog.isEmpty || Double(amountToLog) == nil || Double(amountToLog)! <= 0 {
      errorMessage = "Please enter a valid amount"
      return false
    }
    
    return true
  }
  
  private func clearLogSavingsForm() {
    amountToLog = ""
    notesToLog = ""
  }
}
