//
//  MyActivitiesView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import SwiftUI
import CloudKit

/// View for children to view their assigned activities
struct MyActivitiesView: View {
    @StateObject private var viewModel: MyActivitiesViewModel
    
    init(userProfile: UserProfile) {
        self._viewModel = StateObject(wrappedValue: MyActivitiesViewModel(userProfile: userProfile))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your activities...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.myActivities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "target")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Activities Assigned")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your family admin hasn't assigned any savings activities to you yet. Check back later!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.myActivities) { myActivityProgress in
                        NavigationLink(destination: ActivityDetailView(
                            activity: myActivityProgress.activity,
                            userProfile: viewModel.userProfile
                        )) {
                            MyActivityRow(myActivityProgress: myActivityProgress)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("My Activities")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.refreshActivities()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

struct MyActivityRow: View {
    let myActivityProgress: MyActivityProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Activity Image
                if let pictureAsset = myActivityProgress.activity.picture,
                   let imageURL = pictureAsset.fileURL,
                   let imageData = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                                .font(.title2)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(myActivityProgress.activity.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if myActivityProgress.activity.isExpired {
                        Text("Expired")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(myActivityProgress.activity.daysRemaining) days remaining")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Last saved: \(lastSavedText)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if myActivityProgress.hasCompletedGoal {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                    } else {
                        Text(String(format: "%.0f%%", myActivityProgress.myProgressPercentage * 100))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(myActivityProgress.myProgressText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if !myActivityProgress.hasCompletedGoal {
                        Text("$\(String(format: "%.2f", myActivityProgress.amountRemaining)) to go")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                ProgressView(value: myActivityProgress.myProgressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: myActivityProgress.hasCompletedGoal ? .yellow : .blue))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var lastSavedText: String {
        guard let lastEntry = myActivityProgress.mySavingsEntries.first else {
            return "Never"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: lastEntry.dateLogged)
    }
}

#Preview {
    @Previewable @State var sampleRecord = {
        let record = CKRecord(recordType: "UserProfile")
        record["name"] = "Child User"
        record["email"] = "child@example.com"
        record["appleUserIdentifier"] = "001234.567890abcdef"
        return record
    }()
    
    let userProfile = UserProfile(record: sampleRecord)
    MyActivitiesView(userProfile: userProfile)
}