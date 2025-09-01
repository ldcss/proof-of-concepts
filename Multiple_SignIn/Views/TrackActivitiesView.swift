//
//  TrackActivitiesView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import SwiftUI
import CloudKit

/// View for tracking all family activities (Father's role)
struct TrackActivitiesView: View {
    @StateObject private var viewModel: TrackActivitiesViewModel
    
    init(family: Family) {
        self._viewModel = StateObject(wrappedValue: TrackActivitiesViewModel(family: family))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading activities...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.activities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Activities Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create your first activity to start tracking savings goals for your family members.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.activities) { activityProgress in
                        ActivityProgressRow(activityProgress: activityProgress)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Track Activities")
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

struct ActivityProgressRow: View {
    let activityProgress: ActivityProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Activity Image
                if let pictureAsset = activityProgress.activity.picture,
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
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(activityProgress.activity.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("Assigned to \(activityProgress.activity.assignedTo.count) member(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if activityProgress.activity.isExpired {
                        Text("Expired")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(activityProgress.activity.daysRemaining) days remaining")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if activityProgress.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Text(String(format: "%.0f%%", activityProgress.progressPercentage * 100))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activityProgress.progressText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                ProgressView(value: activityProgress.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: activityProgress.isCompleted ? .green : .blue))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    @Previewable @State var sampleRecord = {
        let record = CKRecord(recordType: "Family")
        record["inviteCode"] = "ABC-123"
        return record
    }()
    
    let family = Family(record: sampleRecord)
    TrackActivitiesView(family: family)
}
