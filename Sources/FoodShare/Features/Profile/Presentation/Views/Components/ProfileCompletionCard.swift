//
//  ProfileCompletionCard.swift
//  FoodShare
//
//  Displays profile completion progress with circular progress ring.
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Profile Completion Card

struct ProfileCompletionCard: View {
    @Environment(\.translationService) private var t
    let completion: ProfileCompletion
    let onTap: () -> Void

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progressColor: Color {
        switch completion.percentage {
        case 0 ..< 30: .DesignSystem.error
        case 30 ..< 70: .DesignSystem.brandOrange
        default: .DesignSystem.brandGreen
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            progressRing

            contentSection

            Spacer()

            Image(systemName: "chevron.right")
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .onTapGesture {
            onTap()
            HapticManager.light()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.t("profile.completion_accessibility", args: ["percent": "\(Int(completion.percentage))"]))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.DesignSystem.glassBackground, lineWidth: 8)
                .frame(width: 70, height: 70)

            Circle()
                .trim(from: 0, to: animatedProgress / 100)
                .stroke(
                    LinearGradient(
                        colors: [progressColor, progressColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round),
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int(animatedProgress))%")
                    .font(.LiquidGlass.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.DesignSystem.text)
                    .contentTransition(.numericText())
            }
        }
        .onAppear {
            let animation: Animation = reduceMotion
                ? .linear(duration: 0.1)
                : .spring(response: 1.0, dampingFraction: 0.7)

            withAnimation(animation) {
                animatedProgress = completion.percentage
            }
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(t.t("profile.complete_profile"))
                .font(.LiquidGlass.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)

            if let nextStep = completion.nextStep {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.DesignSystem.accentYellow)

                    Text(t.t("profile.next_step", args: ["step": nextStep]))
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            Text(t.t("profile.complete_profile_benefit"))
                .font(.LiquidGlass.captionSmall)
                .foregroundStyle(Color.DesignSystem.brandGreen)
                .padding(.top, Spacing.xxs)
        }
    }
}

// MARK: - Profile Completion Model

/// Model representing profile completion status
struct ProfileCompletion {
    let percentage: Double
    let nextStep: String?
    let missingFields: [String]

    static let complete = ProfileCompletion(
        percentage: 100,
        nextStep: nil,
        missingFields: [],
    )

    static func calculate(from profile: UserProfile) -> ProfileCompletion {
        var fieldsPresent = 0
        var missingFields: [String] = []
        let totalFields = 6

        if !profile.nickname.isEmpty { fieldsPresent += 1 } else { missingFields.append("nickname") }
        if profile.avatarUrl != nil { fieldsPresent += 1 } else { missingFields.append("avatar") }
        if let bio = profile.bio, !bio.isEmpty { fieldsPresent += 1 } else { missingFields.append("bio") }
        if let location = profile.location,
           !location.isEmpty { fieldsPresent += 1 } else { missingFields.append("location") }
        if profile.ratingCount > 0 { fieldsPresent += 1 } else { missingFields.append("reviews") }
        if profile.itemsShared > 0 || profile.itemsReceived > 0 { fieldsPresent += 1 }
        else { missingFields.append("activity") }

        let percentage = Double(fieldsPresent) / Double(totalFields) * 100
        let nextStep = missingFields.first.map { ProfileCompletion.localizedStep(for: $0) }

        return ProfileCompletion(
            percentage: percentage,
            nextStep: nextStep,
            missingFields: missingFields,
        )
    }

    private static func localizedStep(for field: String) -> String {
        switch field {
        case "avatar": "Add a profile photo"
        case "bio": "Write a bio"
        case "location": "Add your location"
        case "reviews": "Get your first review"
        case "activity": "Share or receive an item"
        default: "Complete your profile"
        }
    }
}
