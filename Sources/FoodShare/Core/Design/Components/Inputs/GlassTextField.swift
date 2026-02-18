//
//  GlassTextField.swift
//  Foodshare
//
//  Liquid Glass v26 Text Input Component with focus animations
//  CareEcho-inspired blue/cyan gradient effects and layered glass styling
//


#if !SKIP
import SwiftUI

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType

    @FocusState private var isFocused: Bool
    @State private var isSecureVisible = false

    init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
    ) {
        self.placeholder = placeholder
        _text = text
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(iconGradient)
                    .frame(width: 26.0)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: isFocused)
            }

            Group {
                if isSecure, !isSecureVisible {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .tint(Color.DesignSystem.accentBlue)
            .focused($isFocused)
            .accessibilityLabel(placeholder)

            if isSecure {
                Button {
                    withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
                        isSecureVisible.toggle()
                    }
                } label: {
                    Image(systemName: isSecureVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(isFocused ? 0.65 : 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSecureVisible ? "Hide password" : "Show password")
                .accessibilityHint("Toggles password visibility")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(layeredGlassBackground)
        .shadow(
            color: isFocused ? Color.DesignSystem.accentBlue.opacity(0.3) : Color.black.opacity(0.1),
            radius: isFocused ? 12 : 6,
            x: 0,
            y: isFocused ? 6 : 3,
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
        // Note: Do NOT use .drawingGroup() here - it breaks TextField interactivity
    }

    // MARK: - Icon Gradient (CareEcho-style)

    private var iconGradient: LinearGradient {
        if isFocused {
            LinearGradient(
                colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.6), Color.white.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }
    }

    // MARK: - Layered Glass Background (CareEcho-style)

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
                        endPoint: .bottom,
                    ),
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderGradient, lineWidth: isFocused ? 2 : 1.5),
        )
    }

    // MARK: - Border Gradient

    private var borderGradient: LinearGradient {
        if isFocused {
            LinearGradient(
                colors: [Color.DesignSystem.accentBlue.opacity(0.6), Color.DesignSystem.accentCyan.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }
    }
}

// MARK: - GlassSecureField (Convenience wrapper)

struct GlassSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String

    init(_ placeholder: String, text: Binding<String>, icon: String) {
        self.placeholder = placeholder
        _text = text
        self.icon = icon
    }

    var body: some View {
        GlassTextField(placeholder, text: $text, icon: icon, isSecure: true)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: Spacing.md) {
            GlassTextField("Email", text: .constant(""), icon: "envelope.fill")
            GlassTextField("Password", text: .constant(""), icon: "lock.fill", isSecure: true)
            GlassSecureField("Confirm Password", text: .constant(""), icon: "lock.fill")
        }
        .padding()
    }
}

#endif
