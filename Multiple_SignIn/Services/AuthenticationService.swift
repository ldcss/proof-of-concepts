//
//  AuthenticationService.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 28/08/25.
//

import Foundation
import AuthenticationServices
import Combine

/// Protocol defining authentication operations
protocol AuthenticationServiceProtocol {
    func signInWithApple() -> AnyPublisher<AppleSignInResult, Error>
}

/// Service responsible for handling Apple Sign In authentication
final class AuthenticationService: NSObject, AuthenticationServiceProtocol {
    
    // MARK: - Properties
    
    private var currentAuthorizationSubject: PassthroughSubject<AppleSignInResult, Error>?
    
    // MARK: - Public Methods
    
    /// Initiates Sign in with Apple flow
    func signInWithApple() -> AnyPublisher<AppleSignInResult, Error> {
        let subject = PassthroughSubject<AppleSignInResult, Error>()
        currentAuthorizationSubject = subject
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
        
        return subject.eraseToAnyPublisher()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            currentAuthorizationSubject?.send(completion: .failure(AuthenticationError.invalidCredentials))
            return
        }
        
        let userIdentifier = appleIDCredential.user
        let fullName = appleIDCredential.fullName
        let email = appleIDCredential.email
        
        let name = PersonNameComponentsFormatter().string(from: fullName ?? PersonNameComponents())
      print("appleId", appleIDCredential.email, appleIDCredential.fullName, appleIDCredential.user, appleIDCredential.realUserStatus, appleIDCredential.state)
        let result = AppleSignInResult(
            userIdentifier: userIdentifier,
            email: email ?? "",
            fullName: name.isEmpty ? "Unknown User" : name
        )
        
        currentAuthorizationSubject?.send(result)
        currentAuthorizationSubject?.send(completion: .finished)
        currentAuthorizationSubject = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        currentAuthorizationSubject?.send(completion: .failure(AuthenticationError.authorizationFailed(error)))
        currentAuthorizationSubject = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Supporting Types

/// Result of Apple Sign In authentication
struct AppleSignInResult {
    let userIdentifier: String
    let email: String
    let fullName: String
}

/// Authentication related errors
enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case authorizationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials received from Apple Sign In"
        case .authorizationFailed(let error):
            return "Apple Sign In failed: \(error.localizedDescription)"
        }
    }
}
