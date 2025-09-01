//
//  OnboardingView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import SwiftUI

/// Main onboarding view presenting the two flow options
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var appState: AppStateViewModel
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            VStack(spacing: 32) {
                Spacer()
                
                // App Header
                VStack(spacing: 16) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Family Groups")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Create or join a family group to stay connected")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: viewModel.navigateToFatherAuth) {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Sign in as Father/Admin")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: viewModel.navigateToJoinFamily) {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Join a Family")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationDestination(for: FlowDestination.self) { destination in
                switch destination {
                case .fatherAuth:
                    FatherAuthView()
                        .environmentObject(appState)
                case .joinFamily:
                    JoinFamilyView()
                        .environmentObject(appState)
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
    }
}

#Preview {
    OnboardingView()
}
