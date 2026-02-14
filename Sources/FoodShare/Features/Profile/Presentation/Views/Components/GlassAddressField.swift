//
//  GlassAddressField.swift
//  FoodShare
//
//  Tappable address field component following Liquid Glass design system
//  Shows current address with tap action to open address picker
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Glass Address Field

struct GlassAddressField: View {
    @Environment(\.translationService) private var t

    let address: EditableAddress
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.light()
            onTap()
        }) {
            HStack(spacing: Spacing.md) {
                // Location icon with glass background
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.brandBlue.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.DesignSystem.brandBlue)
                }

                // Label and address content
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(t.t("profile.edit.address"))
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    if address.hasContent {
                        Text(address.formattedShort.isEmpty ? address.formattedFull : address.formattedShort)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.text)
                            .lineLimit(1)
                    } else {
                        Text(t.t("profile.edit.add_address"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.textTertiary)
                    }
                }

                Spacer()

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(layeredGlassBackground)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
    }

    // MARK: - Layered Glass Background

    private var layeredGlassBackground: some View {
        ZStack {
            // Base glass fill
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))

            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            // Empty address
            GlassAddressField(
                address: .empty,
                onTap: { print("Tapped empty") }
            )

            // Address with content
            GlassAddressField(
                address: .fixture(),
                onTap: { print("Tapped with content") }
            )

            // Address with only city
            GlassAddressField(
                address: EditableAddress(
                    addressLine1: "",
                    addressLine2: "",
                    city: "London",
                    stateProvince: "UK",
                    postalCode: "",
                    country: "",
                    latitude: nil,
                    longitude: nil
                ),
                onTap: { print("Tapped city only") }
            )
        }
        .padding()
    }
}
