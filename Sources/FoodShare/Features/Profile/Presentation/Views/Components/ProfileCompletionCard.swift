//
//  ProfileCompletionCard.swift
//  FoodShare
//
//  Displays profile completion progress with circular progress ring.
//


#if !SKIP
import SwiftUI

// MARK: - Profile Completion Card

struct ProfileCompletionCard: View {
    @Environment(\.translationService) private var t
    let completion: ProfileCompletion
    let onTap: () -> Void

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

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
        #if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.t("profile.completion_accessibility", args: ["percent": "\(Int(completion.percentage))"]))
        .accessibilityAddTraits(.isButton)
        #endif
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.DesignSystem.glassBackground, lineWidth: 8)
                .frame(width: 70.0, height: 70)

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
                .frame(width: 70.0, height: 70)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int(animatedProgress))%")
                    .font(.LiquidGlass.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.DesignSystem.text)
                    #if !SKIP
                    .contentTransition(.numericText())
                    #endif
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


#endif
