//
//  ProfileView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import SwiftUI
import PhotosUI
import CloudKit

/// View for managing user profile
struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppStateViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCreateActivity = false
    @State private var showTrackActivities = false
    @State private var showMyActivities = false
    
    init(userProfile: UserProfile, family: Family?) {
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(userProfile: userProfile, family: family))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                profileHeader
                
                // User Information
                userInfoSection
                
                // Family Information
                if let family = viewModel.family {
                    familyInfoSection(family: family)
                    
                    // Activities Section - Role-based UI
                    activitiesSection(family: family)
                }
                
                // Logout Button
                logoutSection
                
                Spacer(minLength: 32)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit Profile") {
                    viewModel.showImagePicker = true
                }
                .foregroundColor(.blue)
            }
        }
        .photosPicker(
            isPresented: $viewModel.showImagePicker,
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        viewModel.updateProfileImage(image)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateActivity) {
            if let family = viewModel.family {
                CreateActivityView(family: family)
            }
        }
        .sheet(isPresented: $showTrackActivities) {
            if let family = viewModel.family {
                TrackActivitiesView(family: family)
            }
        }
        .sheet(isPresented: $showMyActivities) {
            MyActivitiesView(userProfile: viewModel.userProfile)
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
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                
                if let profileImage = viewModel.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                }
                
                Button(action: { viewModel.showImagePicker = true }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .offset(x: 40, y: 40)
            }
            
            Text(viewModel.userProfile.name)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.userProfile.email)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("User Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                InfoRow(title: "Name", value: viewModel.userProfile.name)
                InfoRow(title: "Email", value: viewModel.userProfile.email)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private func familyInfoSection(family: Family) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Family Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Invite Code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack {
                        Text(family.inviteCode)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Button(action: viewModel.copyInviteCode) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Role")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(isCreator(family: family) ? "Family Admin" : "Family Member")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isCreator(family: family) ? .blue : .green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private func activitiesSection(family: Family) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activities")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                if isCreator(family: family) {
                    // Father/Creator UI
                    Button(action: { showCreateActivity = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New Activity")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button(action: { showTrackActivities = true }) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Track All Activities")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    // Child/Member UI
                    Button(action: { showMyActivities = true }) {
                        HStack {
                            Image(systemName: "target")
                            Text("My Activities")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var logoutSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                appState.logout()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private func isCreator(family: Family) -> Bool {
        guard let creatorReference = family.creatorReference else { return false }
        return creatorReference.recordID == viewModel.userProfile.record.recordID
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    @Previewable @State var sampleRecord = {
        let record = CKRecord(recordType: "UserProfile")
        record["name"] = "John Doe"
        record["email"] = "john@example.com"
        record["appleUserIdentifier"] = "001234.567890abcdef"
        return record
    }()
    
    let userProfile = UserProfile(record: sampleRecord)
    
    NavigationView {
        ProfileView(userProfile: userProfile, family: nil)
    }
}
