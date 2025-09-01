//
//  ActivityDetailView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import SwiftUI
import CloudKit

/// View for activity details and logging savings (Child's role)
struct ActivityDetailView: View {
    @StateObject private var viewModel: ActivityDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(activity: Activity, userProfile: UserProfile) {
        self._viewModel = StateObject(wrappedValue: ActivityDetailViewModel(
            activity: activity,
            userProfile: userProfile
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Activity Header
                activityHeaderSection
                
                // Progress Section
                progressSection
                
                // Action Button
                actionButtonSection
                
                // Savings History
                savingsHistorySection
            }
            .padding()
        }
        .navigationTitle(viewModel.activity.title)
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.refreshSavingsEntries()
        }
        .sheet(isPresented: $viewModel.showLogSavingsSheet) {
            logSavingsSheet
        }
        .overlay(
            Group {
                if viewModel.isLoading {
                    LoadingOverlay()
                }
            }
        )
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private var activityHeaderSection: some View {
        VStack(spacing: 16) {
            // Activity Image
            if let pictureAsset = viewModel.activity.picture,
               let imageURL = pictureAsset.fileURL,
               let imageData = try? Data(contentsOf: imageURL),
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.2))
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "target")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    )
            }
            
            // Activity Info
            VStack(spacing: 8) {
                Text(viewModel.activity.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("Goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", viewModel.activity.moneyGoal))")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack {
                        Text("End Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.activity.endDate, style: .date)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack {
                        Text("Days Left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.activity.daysRemaining)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.activity.isExpired ? .red : .blue)
                    }
                }
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Progress Header
            HStack {
                Text("Your Progress")
                    .font(.headline)
                Spacer()
                if viewModel.hasCompletedGoal {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                }
            }
            
            // Progress Bar and Text
            VStack(spacing: 8) {
                ProgressView(value: viewModel.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: viewModel.hasCompletedGoal ? .yellow : .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    Text(viewModel.progressText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.0f", viewModel.progressPercentage * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            if !viewModel.hasCompletedGoal {
                Text("$\(String(format: "%.2f", viewModel.amountRemaining)) remaining to reach your goal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("🎉 Congratulations! You've reached your goal!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtonSection: some View {
        Button(action: viewModel.showLogSavings) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Log My Savings")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.activity.isExpired ? Color.gray : Color.blue)
            .cornerRadius(12)
        }
        .disabled(viewModel.activity.isExpired)
    }
    
    private var savingsHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Savings History")
                .font(.headline)
            
            if viewModel.mySavingsEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No savings logged yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Start logging your savings to track your progress!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.mySavingsEntries, id: \.id) { entry in
                        SavingsEntryRow(entry: entry)
                    }
                }
            }
        }
    }
    
    private var logSavingsSheet: some View {
        NavigationView {
            Form {
                Section("Log Your Savings") {
                    HStack {
                        Text("Amount Saved")
                        Spacer()
                        TextField("0.00", text: $viewModel.amountToLog)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    
                    TextField("Notes (optional)", text: $viewModel.notesToLog, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Savings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.dismissLogSavings()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.logSavings()
                    }
                    .disabled(viewModel.isLoggingSavings || viewModel.amountToLog.isEmpty)
                }
            }
            .overlay(
                Group {
                    if viewModel.isLoggingSavings {
                        LoadingOverlay()
                    }
                }
            )
        }
    }
}

struct SavingsEntryRow: View {
    let entry: SavingsEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.formattedAmount)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Text(entry.formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    @Previewable @State var activityRecord = {
        let record = CKRecord(recordType: "Activity")
        record["title"] = "New Bicycle"
        record["moneyGoal"] = 250.0
        record["endDate"] = Date().addingTimeInterval(30 * 24 * 60 * 60)
        return record
    }()
    
    @Previewable @State var userRecord = {
        let record = CKRecord(recordType: "UserProfile")
        record["name"] = "Child User"
        record["email"] = "child@example.com"
        record["appleUserIdentifier"] = "001234.567890abcdef"
        return record
    }()
    
    let activity = Activity(record: activityRecord)
    let userProfile = UserProfile(record: userRecord)
    
    NavigationView {
        ActivityDetailView(activity: activity, userProfile: userProfile)
    }
}