// FlowDay
// LoginView_Updated.swift
// Updated login interface with Sign in with Apple and Google Sign-In support.

import SwiftUI
import AuthenticationServices
import GoogleSignIn

// MARK: - Sign in with Apple Button Wrapper

struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    let onAuthorization: (ASAuthorization) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleSignInTapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onAuthorization: onAuthorization)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onAuthorization: (ASAuthorization) -> Void

        init(onAuthorization: @escaping (ASAuthorization) -> Void) {
            self.onAuthorization = onAuthorization
        }

        @objc func handleSignInTapped() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        // MARK: - ASAuthorizationControllerDelegate

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            onAuthorization(authorization)
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithError error: Error
        ) {
            print("Sign in with Apple error: \(error.localizedDescription)")
        }

        // MARK: - ASAuthorizationControllerPresentationContextProviding

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
                return ASPresentationAnchor()
            }
            return window
        }
    }
}

// MARK: - Google Sign-In Button Wrapper

struct GoogleSignInButtonRepresentable: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleGoogleSignIn), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func handleGoogleSignIn() {
            action()
        }
    }
}

// MARK: - Main Login View

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var showEmailSheet = false
    @State private var showErrorAlert = false
    @State private var emailText = ""
    @State private var passwordText = ""

    var body: some View {
        ZStack {
            Color.fdBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Section
                headerSection
                    .padding(.top, 48)
                    .padding(.bottom, 40)

                // Feature Highlights
                featureHighlightsSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)

                Spacer()

                // Authentication Buttons
                authenticationSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Terms & Privacy Links
                termsAndPrivacySection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            emailLoginSheet
        }
        .alert("Authentication Error", isPresented: $showErrorAlert) {
            Button("Dismiss") { }
        } message: {
            Text(authManager.errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: authManager.errorMessage) { oldValue, newValue in
            if newValue != nil {
                showErrorAlert = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("FlowDay")
                .font(.system(size: 48, weight: .bold, design: .default))
                .fontDesign(.serif)
                .foregroundColor(.fdAccent)

            Text("Master Your Flow, Maximize Your Day")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Feature Highlights Section

    private var featureHighlightsSection: some View {
        VStack(spacing: 16) {
            FeatureHighlight(emoji: "🎯", title: "Focus Mode", description: "Deep work sessions optimized for flow")
            FeatureHighlight(emoji: "📊", title: "Smart Analytics", description: "Track productivity patterns over time")
            FeatureHighlight(emoji: "🔔", title: "Intelligent Reminders", description: "Context-aware notifications when you need them")
        }
    }

    // MARK: - Authentication Section

    private var authenticationSection: some View {
        VStack(spacing: 12) {
            // Sign in with Apple
            SignInWithAppleButtonRepresentable { authorization in
                Task {
                    await authManager.signInWithApple(authorization: authorization)
                }
            }
            .frame(height: 50)
            .cornerRadius(8)

            // Sign in with Google
            Button(action: {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    authManager.errorMessage = "Unable to present Google Sign-In"
                    return
                }

                Task {
                    await authManager.signInWithGoogle(presenting: rootViewController)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))
                    Text("Sign in with Google")
                        .font(.fdBody)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor(.white)
                .background(Color(red: 0.2, green: 0.5, blue: 1.0))
                .cornerRadius(8)
            }
            .disabled(authManager.isLoading)

            // Divider
            HStack {
                VStack { Divider() }
                Text("or")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.gray)
                VStack { Divider() }
            }
            .padding(.vertical, 8)

            // Email Sign-in
            Button(action: { showEmailSheet = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20))
                    Text("Sign in with Email")
                        .font(.fdBody)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor(.fdAccent)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.fdAccent, lineWidth: 2)
                )
            }
            .disabled(authManager.isLoading)

            // Loading Indicator
            if authManager.isLoading {
                ProgressView()
                    .tint(.fdAccent)
                    .padding(.top, 12)
            }
        }
    }

    // MARK: - Email Login Sheet

    private var emailLoginSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    TextField("Email", text: $emailText)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    SecureField("Password", text: $passwordText)
                        .textContentType(.password)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                Button(action: {
                    Task {
                        await authManager.signInWithEmail(email: emailText, password: passwordText)
                        if authManager.isAuthenticated {
                            showEmailSheet = false
                        }
                    }
                }) {
                    Text("Sign In")
                        .font(.fdBody)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(Color.fdAccent)
                        .cornerRadius(8)
                }
                .disabled(emailText.isEmpty || passwordText.isEmpty || authManager.isLoading)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Email Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Terms & Privacy Section

    private var termsAndPrivacySection: some View {
        VStack(spacing: 12) {
            Text("By signing in, you agree to our")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Link("Terms of Service", destination: URL(string: "https://flowday.app/terms")!)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.fdAccent)

                Text("and")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)

                Link("Privacy Policy", destination: URL(string: "https://flowday.app/privacy")!)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.fdAccent)
            }
        }
    }
}

// MARK: - Feature Highlight Component

struct FeatureHighlight: View {
    let emoji: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.fdBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.fdText)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.fdTextSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.fdSurface)
        .cornerRadius(8)
        .shadow(color: Color.fdText.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environment(AuthManager())
}
