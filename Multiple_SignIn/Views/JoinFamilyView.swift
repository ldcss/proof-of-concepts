//
//  JoinFamilyView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import SwiftUI

/// View for the Join Family flow
struct JoinFamilyView: View {
    @StateObject private var viewModel = JoinFamilyViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppStateViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            if !viewModel.isAuthenticated {
                // Invite code entry state
                inviteCodeContent
            } else {
                // Loading state after authentication - redirect handled by AppState
                loadingContent
            }
        }
        .navigationTitle("Join Family")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
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
        .onAppear {
            viewModel.setAppState(appState)
        }
    }
    
    private var inviteCodeContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Join a Family")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Enter the invite code shared by your family member to join their group.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                TextField("Enter invite code (e.g., ABC-123)", text: $viewModel.inviteCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isTextFieldFocused)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Button(action: viewModel.validateInviteCode) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.inviteCode.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(viewModel.inviteCode.isEmpty)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private var loadingContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Joining family...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        JoinFamilyView()
    }
}
