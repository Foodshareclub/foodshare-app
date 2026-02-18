//
//  GlassDetailRow.swift
//  Foodshare
//
//  Liquid Glass v26 unified detail row component
//  Consolidates DetailRow and FridgeInfoRow patterns
//


#if !SKIP
import SwiftUI

struct GlassDetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var showChevron: Bool = false
    var action: (() -> Void)? = nil

    @State private var hasAppeared = false

    var body: some View {
        Group {
            if let action {
                Button(action: {
                    action()
                    HapticManager.light()
                }) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75).delay(0.03)) {
                hasAppeared = true
            }
        }
    }

    private var rowContent: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                // Icon with colored background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32.0, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(iconColor)
                }

                // Label
                Text(label)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.text)
            }

            Spacer()

            // Value
            Text(value)
                .font(.DesignSystem.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(.DesignSystem.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)

            // Optional chevron for actionable rows
            if showChevron || action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.DesignSystem.textTertiary)
            }
        }
        .padding(.vertical, Spacing.xs)
        #if !SKIP
        .contentShape(Rectangle())
        #endif
    }
}

// MARK: - Alternate Styles

extension GlassDetailRow {
    /// Creates a compact row variant with smaller icon
    static func compact(
        icon: String,
        iconColor: Color,
        label: String,
        value: String
    ) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            Spacer()

            Text(value)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.text)
        }
    }
}

// MARK: - Staggered Animation Support

struct GlassDetailRowGroup: View {
    let rows: [GlassDetailRowData]
    var staggerDelay: Double = 0.05

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                GlassDetailRow(
                    icon: row.icon,
                    iconColor: row.iconColor,
                    label: row.label,
                    value: row.value,
                    showChevron: row.showChevron,
                    action: row.action
                )
                .staggeredAppearance(index: index, staggerDelay: staggerDelay)
            }
        }
    }
}

struct GlassDetailRowData: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var showChevron: Bool = false
    var action: (() -> Void)? = nil
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.lg) {
        VStack(spacing: Spacing.sm) {
            GlassDetailRow(
                icon: "clock.fill",
                iconColor: .orange,
                label: "Available",
                value: "Today, 2:00 PM - 6:00 PM"
            )

            GlassDetailRow(
                icon: "leaf.fill",
                iconColor: .DesignSystem.brandGreen,
                label: "Type",
                value: "Fresh Produce"
            )

            GlassDetailRow(
                icon: "calendar.badge.clock",
                iconColor: .DesignSystem.textSecondary,
                label: "Posted",
                value: "Jan 15, 2026"
            )

            GlassDetailRow(
                icon: "person.fill",
                iconColor: .DesignSystem.brandBlue,
                label: "Shared by",
                value: "Sarah M.",
                showChevron: true,
                action: {}
            )
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#endif
