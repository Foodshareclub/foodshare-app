//
//  GlassTextArea.swift
//  FoodShare
//
//  Liquid Glass multi-line text input component with focus animations
//  Matches GlassTextField styling for consistent form UX
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Text Area

/// A multi-line text input component with Liquid Glass styling.
///
/// Features:
/// - Icon support with focus-responsive gradient
/// - Placeholder text when empty
/// - Focus state animations with border gradient
/// - Character limit support with counter display
/// - Configurable height constraints
struct GlassTextArea: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let characterLimit: Int?
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        characterLimit: Int? = nil,
        minHeight: CGFloat = 80,
        maxHeight: CGFloat = 120
    ) {
        self.placeholder = placeholder
        _text = text
        self.icon = icon
        self.characterLimit = characterLimit
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconGradient)
                        .font(.system(size: 18, weight: .medium))
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
                        .padding(.top, Spacing.xs)
                }

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.top, 2)
                    }

                    TextEditor(text: $text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white)
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .frame(minHeight: minHeight, maxHeight: maxHeight)
                        .tint(Color.DesignSystem.accentBlue)
                        .accessibilityLabel(placeholder)
                }
            }
            .padding(Spacing.md)
            .background(layeredGlassBackground)
            .shadow(
                color: isFocused ? Color.DesignSystem.accentBlue.opacity(0.3) : Color.black.opacity(0.1),
                radius: isFocused ? 12 : 6,
                x: 0,
                y: isFocused ? 6 : 3
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)

            // Character counter
            if let limit = characterLimit {
                characterCounter(limit: limit)
            }
        }
    }

    // MARK: - Icon Gradient

    private var iconGradient: LinearGradient {
        if isFocused {
            LinearGradient(
                colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.6), Color.white.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Layered Glass Background

    private var layeredGlassBackground: some View {
        ZStack {
            // Base glass fill
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isFocused ? 0.12 : 0.08))

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
                .stroke(borderGradient, lineWidth: isFocused ? 2 : 1.5)
        )
    }

    // MARK: - Border Gradient

    private var borderGradient: LinearGradient {
        if isFocused {
            LinearGradient(
                colors: [Color.DesignSystem.accentBlue.opacity(0.6), Color.DesignSystem.accentCyan.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Character Counter

    @ViewBuilder
    private func characterCounter(limit: Int) -> some View {
        let count = text.count
        let isOverLimit = count > limit

        Text("\(count)/\(limit)")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isOverLimit ? Color.DesignSystem.error : Color.white.opacity(0.5))
            .padding(.trailing, Spacing.xs)
            .animation(.interpolatingSpring(stiffness: 400, damping: 20), value: isOverLimit)
            .accessibilityLabel("\(count) of \(limit) characters")
            .if(isOverLimit) { view in
                view.accessibilityHint("Character limit exceeded")
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            GlassTextArea("Write your bio...", text: .constant(""), icon: "text.quote")

            GlassTextArea(
                "Tell us about yourself",
                text: .constant("I love sharing food with my community!"),
                icon: "person.fill",
                characterLimit: 200
            )

            GlassTextArea(
                "Additional notes",
                text: .constant("This is a longer text that spans multiple lines to demonstrate how the text area handles wrapping and scrolling content."),
                icon: "note.text",
                characterLimit: 500
            )
        }
        .padding()
    }
}
