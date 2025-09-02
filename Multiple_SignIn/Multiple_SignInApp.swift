//
//  Multiple_SignInApp.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import SwiftUI
import CloudKit

@main
struct Multiple_SignInApp: App {
    @StateObject private var appState = AppStateViewModel()
    
    var body: some Scene {
        WindowGroup {
            if appState.isLoading {
                LoadingView()
                    .onAppear {
                        // Attempt to restore session on app launch
                        appState.restoreSessionOnLaunch()
                    }
            } else if appState.isLoggedIn, let userProfile = appState.currentUser {
                ProfileView(userProfile: userProfile, family: appState.currentFamily)
                    .environmentObject(appState)
            } else if appState.showOnboarding {
                OnboardingView()
                    .environmentObject(appState)
            } else {
                LoadingView()
            }
        }
    }
}

/// Simple loading view for app startup
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
