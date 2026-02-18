//
//  FeatureIcon.swift
//  Foodshare
//
//  Liquid Glass v26 - Feature Icon Component
//  CareEcho-inspired feature highlight with glass background and gradient icon
//


#if !SKIP
import SwiftUI

/// Compact feature icon with glass background and gradient icon
/// Used for feature highlights on auth/onboarding screens
struct FeatureIcon: View {
    let icon: String
    let label: String
    let size: Size

    enum Size {
        case small   // 36pt icon, 10pt label
        case medium  // 44pt icon, 12pt label
        case large   // 56pt icon, 14pt label

        var iconFrame: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 44
            case .large: return 56
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }

        var labelSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }

        var spacing: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }
    }

    init(icon: String, label: String, size: Size = .medium) {
        self.icon = icon
        self.label = label
        self.size = size
    }

    var body: some View {
        VStack(spacing: size.spacing) {
            // Icon with glass background
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundStyle(iconGradient)
                .frame(width: size.iconFrame, height: size.iconFrame)
                .background(glassBackground)

            // Label
            Text(label)
                .font(.system(size: size.labelSize, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Icon Gradient (CareEcho-style)

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Feature Row

/// Horizontal feature row with icon and description
/// Used for feature lists on auth/onboarding screens
struct FeatureRow: View {
    let icon: String
    let text: String

    init(icon: String, text: String) {
        self.icon = icon
        self.text = text
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28.0)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

// MARK: - Checkbox Row

/// Animated checkbox row for terms/agreements
/// CareEcho-inspired with gradient checkmark
struct CheckboxRow: View {
    @Binding var isChecked: Bool
    let text: String

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isChecked ? Color.DesignSystem.accentBlue.opacity(0.2) : Color.clear)
                        .frame(width: 26.0, height: 26)

                    RoundedRectangle(cornerRadius: 8)
                        .stroke(checkboxBorderGradient, lineWidth: 2)
                        .frame(width: 26.0, height: 26)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Label
                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var checkboxBorderGradient: LinearGradient {
        if isChecked {
            return LinearGradient(
                colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.4), Color.white.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview("Feature Icons") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 32) {
            // Feature icons row
            HStack(spacing: 24) {
                FeatureIcon(icon: "leaf.fill", label: "Fresh")
                FeatureIcon(icon: "heart.fill", label: "Share")
                FeatureIcon(icon: "map.fill", label: "Local")
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Feature rows
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "checkmark.shield.fill", text: "Verified community members")
                FeatureRow(icon: "location.fill", text: "Find food near you")
                FeatureRow(icon: "clock.fill", text: "Real-time availability")
            }
            .padding(.horizontal)

            Divider()
                .background(Color.white.opacity(0.2))

            // Checkbox rows
            VStack(spacing: 8) {
                CheckboxRow(isChecked: .constant(true), text: "I agree to the Terms of Service")
                CheckboxRow(isChecked: .constant(false), text: "Subscribe to newsletter")
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

#endif
