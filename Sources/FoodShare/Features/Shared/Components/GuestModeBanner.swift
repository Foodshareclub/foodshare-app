//
//  GuestModeBanner.swift
//  Foodshare
//
//  Floating banner indicating guest mode with sign-up CTA
//  Following CareEcho pattern for guest mode UI
//


#if !SKIP
import SwiftUI

struct GuestModeBanner: View {
    @Environment(GuestManager.self) var guestManager
    @Environment(\.translationService) private var t

    @State private var isExpanded = false
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Guest icon
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.warning, Color.DesignSystem.accentYellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(t.t("guest.banner.title"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if isExpanded {
                    Text(t.t("guest.banner.subtitle"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            // Sign Up CTA button
            Button {
                HapticManager.medium()
                guestManager.disableGuestMode()
            } label: {
                Text(t.t("guest.banner.action"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        LinearGradient(
                            colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(bannerBackground)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    private var bannerBackground: some View {
        ZStack {
            // Base glass effect
            RoundedRectangle(cornerRadius: 16)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            // Orange tint overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.warning.opacity(0.15),
                            Color.DesignSystem.accentYellow.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Border
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.warning.opacity(0.4),
                            Color.DesignSystem.accentYellow.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.DesignSystem.warning.opacity(0.2), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AuthBackground(style: .nature)

        VStack {
            GuestModeBanner()
                .padding(.horizontal, Spacing.md)

            Spacer()
        }
        .padding(.top, 60)
    }
    .environment(GuestManager())
}

#endif
