//
//  RootView.swift
//  Foodshare
//
//  Root view using modern Swift 6.2 @Observable pattern
//  Simple flow: Onboarding → Guest → Auth → EmailVerification → Authenticated
//

import Supabase
import SwiftUI

struct RootView: View {
    // Modern @Observable pattern: Use @Environment for @Observable objects
    @Environment(AppState.self) var appState
    @Environment(AuthViewModel.self) var authViewModel // Keep for AuthView bindings
    @Environment(GuestManager.self) var guestManager

    /// CareEcho pattern: Use @AppStorage directly for onboarding state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Translation service for locale-aware view updates
    @Environment(\.translationService) private var translationService

    var body: some View {
        // Observe translationRevision to trigger re-render when translations load
        let _ = translationService.translationRevision

        Group {
            // 1. Check if user hasn't completed onboarding
            if !hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            }
            // 2. Guest mode: Allow direct access to main app
            else if guestManager.isGuestMode {
                MainTabView()
                    .transition(.opacity)
            }
            // 3. Not authenticated and not guest: Show AuthView
            else if !appState.isAuthenticated {
                AuthView()
                    .transition(.opacity)
            }
            // 4. Authenticated but email not confirmed
            else if !appState.isEmailVerified {
                EmailVerificationView()
                    .transition(.opacity)
            }
            // 5. Authenticated with confirmed email
            else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: appState.isAuthenticated)
        .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: guestManager.isGuestMode)
        .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: hasCompletedOnboarding)
        .task {
            // Check for existing session on app launch
            await AuthenticationService.shared.checkCurrentSession()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // swiftlint:disable:next force_unwrapping
    let previewClient = Supabase.SupabaseClient(
        supabaseURL: URL(string: "https://api.foodshare.club")!,
        supabaseKey: "example-key"
    )

    return RootView()
        .environment(AppState.preview)
        .environment(AuthViewModel(supabase: previewClient))
        .environment(GuestManager())
        .environment(FeedViewModel.preview)
}
#endif
