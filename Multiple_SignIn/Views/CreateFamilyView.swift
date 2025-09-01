//
//  CreateFamilyView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import SwiftUI

/// View for the Create Family flow
struct CreateFamilyView: View {
    @StateObject private var viewModel = CreateFamilyViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            if !viewModel.isAuthenticated {
                // Pre-authentication state
                authenticationContent
            } else if viewModel.createdFamily != nil {
                // Success state
                successContent
            } else {
                // Loading state after authentication
                loadingContent
            }
        }
        .navigationTitle("Create Family")
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
    }
    
    private var authenticationContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "house.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Create Your Family")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Sign in with Apple to create a new family group and get your unique invite code.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: viewModel.signInWithApple) {
                HStack {
                    Image(systemName: "applelogo")
                    Text("Sign in with Apple")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    private var loadingContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Creating your family...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Family Created!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Share this invite code with family members:")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if let inviteCode = viewModel.generatedInviteCode {
                VStack(spacing: 16) {
                    Text(inviteCode)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    
                    Button(action: viewModel.copyInviteCode) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Invite Code")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    NavigationView {
        CreateFamilyView()
    }
}