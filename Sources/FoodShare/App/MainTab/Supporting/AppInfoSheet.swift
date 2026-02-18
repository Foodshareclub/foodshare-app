//
//  AppInfoSheet.swift
//  Foodshare
//
//  App information and guidelines sheet
//


#if !SKIP
import SwiftUI

// MARK: - App Info Sheet

struct AppInfoSheet: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t

    var body: some View {
        NavigationStack {
            ZStack {
                appInfoBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        appInfoHeroSection
                        missionSection
                        guidelinesSection
                        safetySection
                        linksSection

                        Spacer().frame(height: Spacing.xl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                }
            }
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .presentationDetents([PresentationDetent.large])
        #if !SKIP
        .presentationDragIndicator(.visible)
        #endif
    }

    private var appInfoBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            LinearGradient(
                colors: [
                    Color.DesignSystem.brandGreen.opacity(0.35),
                    Color.clear,
                    Color.DesignSystem.brandBlue.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
        }
    }

    private var appInfoHeroSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.5),
                                Color.DesignSystem.brandGreen.opacity(0.25),
                                Color.DesignSystem.brandBlue.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 35,
                            endRadius: 95,
                        ),
                    )
                    .frame(width: 150.0, height: 150)
                    .blur(radius: 25)

                AppLogoView(size: .large, showGlow: false, circular: true)
            }

            VStack(spacing: Spacing.xs) {
                Text(t.t("app.name"))
                    .font(.DesignSystem.displayLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.DesignSystem.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .shadow(color: Color.DesignSystem.brandGreen.opacity(0.4), radius: 4, x: 0, y: 2)

                Text(t.t("app.tagline"))
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var missionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AppInfoSectionHeader(icon: "heart.fill", title: t.t("app.mission_title"), color: .DesignSystem.brandGreen)

            Text(t.t("app.mission_description"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
        }
        .appInfoGlassCard()
    }

    private var guidelinesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AppInfoSectionHeader(
                icon: "list.bullet.clipboard.fill",
                title: t.t("app.guidelines_title"),
                color: .DesignSystem.brandGreen,
            )

            VStack(spacing: Spacing.sm) {
                AppInfoGuidelineRow(
                    icon: "hand.raised.fill",
                    title: t.t("app.guidelines.respectful_title"),
                    description: t.t("app.guidelines.respectful_desc"),
                )

                AppInfoGuidelineRow(
                    icon: "leaf.fill",
                    title: t.t("app.guidelines.responsible_title"),
                    description: t.t("app.guidelines.responsible_desc"),
                )

                AppInfoGuidelineRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: t.t("app.guidelines.communicate_title"),
                    description: t.t("app.guidelines.communicate_desc"),
                )

                AppInfoGuidelineRow(
                    icon: "mappin.and.ellipse",
                    title: t.t("app.guidelines.safe_title"),
                    description: t.t("app.guidelines.safe_desc"),
                )

                AppInfoGuidelineRow(
                    icon: "flag.fill",
                    title: t.t("app.guidelines.report_title"),
                    description: t.t("app.guidelines.report_desc"),
                )
            }
        }
        .appInfoGlassCard()
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AppInfoSectionHeader(icon: "checkmark.shield.fill", title: t.t("app.safety_title"), color: .DesignSystem.warning)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                AppInfoSafetyPoint(text: t.t("app.safety.tip1"))
                AppInfoSafetyPoint(text: t.t("app.safety.tip2"))
                AppInfoSafetyPoint(text: t.t("app.safety.tip3"))
                AppInfoSafetyPoint(text: t.t("app.safety.tip4"))
            }
        }
        .appInfoGlassCard()
    }

    private var linksSection: some View {
        VStack(spacing: Spacing.sm) {
            AppInfoLinkButton(title: t.t("app.links.terms"), icon: "doc.text.fill") {}
            AppInfoLinkButton(title: t.t("app.links.privacy"), icon: "lock.shield.fill") {}
            AppInfoLinkButton(title: t.t("app.links.help"), icon: "questionmark.circle.fill") {}
        }
    }
}

// MARK: - App Info Supporting Views

private struct AppInfoSectionHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.DesignSystem.headlineSmall)
                .foregroundColor(color)

            Text(title)
                .font(.DesignSystem.titleLarge)
                .foregroundColor(.white)
        }
    }
}

private struct AppInfoGuidelineRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.DesignSystem.brandGreen)
                .frame(width: 24.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.DesignSystem.labelLarge)
                    .foregroundColor(.white)

                Text(description)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

private struct AppInfoSafetyPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.DesignSystem.warning)

            Text(text)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

private struct AppInfoLinkButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.DesignSystem.brandGreen)

                Text(title)
                    .font(.DesignSystem.labelLarge)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.DesignSystem.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
        }
        .buttonStyle(.plain)
    }
}

extension View {
    fileprivate func appInfoGlassCard() -> some View {
        padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.DesignSystem.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
    }
}

#endif
