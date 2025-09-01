//
//  FatherAuthView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import SwiftUI

/// View for Father/Admin authentication flow
struct FatherAuthView: View {
    @StateObject private var viewModel = FatherAuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppStateViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            if !viewModel.isAuthenticated {
                // Pre-authentication state
                authenticationContent
            } else {
                // Redirect handled by AppState
                EmptyView()
            }
        }
        .navigationTitle("Father Sign In")
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
    
    private var authenticationContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "person.badge.key")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Father/Admin Sign In")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Sign in as the family administrator. If you don't have a family yet, one will be created for you. If you're already a family member, you cannot create a new family.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: viewModel.authenticateAsFather) {
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
}

#Preview {
    NavigationView {
        FatherAuthView()
    }
}
