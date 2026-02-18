
#if !SKIP
import SwiftUI

// MARK: - Glass Recovery Banner

/// Animated banner shown when the app restores a previous session
public struct GlassRecoveryBanner: View {

    // MARK: - Properties

    @Binding var isVisible: Bool
    let pendingOperationsCount: Int
    let onDismiss: (() -> Void)?
    let onRetryOperations: (() -> Void)?

    @State private var opacity: Double = 0
    @State private var offsetY: CGFloat = -100
    @State private var iconRotation: Double = 0
    @State private var glowIntensity: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    private let autoDismissDelay: TimeInterval = 5.0

    // MARK: - Initialization

    public init(
        isVisible: Binding<Bool>,
        pendingOperationsCount: Int = 0,
        onDismiss: (() -> Void)? = nil,
        onRetryOperations: (() -> Void)? = nil,
    ) {
        self._isVisible = isVisible
        self.pendingOperationsCount = pendingOperationsCount
        self.onDismiss = onDismiss
        self.onRetryOperations = onRetryOperations
    }

    // MARK: - Body

    public var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                bannerContent
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(glassBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    .shadow(
                        color: Color.DesignSystem.brandGreen.opacity(glowIntensity * 0.3),
                        radius: 20,
                        x: 0,
                        y: 5,
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                    .offset(y: offsetY)
                    .opacity(opacity)
                    .gesture(dismissGesture)

                Spacer()
            }
            .transition(.opacity)
            .onAppear(perform: animateIn)
            .task {
                #if SKIP
                try? await Task.sleep(nanoseconds: UInt64(autoDismissDelay * 1_000_000_000))
                #else
                try? await Task.sleep(for: .seconds(autoDismissDelay))
                #endif
                dismiss()
            }
        }
    }

    // MARK: - Subviews

    private var bannerContent: some View {
        HStack(spacing: Spacing.sm) {
            // Animated checkmark icon
            ZStack {
                Circle()
                    .fill(Color.DesignSystem.brandGreen.opacity(0.2))
                    .frame(width: 40.0, height: 40)

                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.DesignSystem.brandGreen)
                    .rotationEffect(.degrees(iconRotation))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Session Restored")
                    .font(.DesignSystem.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                if pendingOperationsCount > 0 {
                    Text(
                        "\(pendingOperationsCount) pending \(pendingOperationsCount == 1 ? "action" : "actions") to sync",
                    )
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                } else {
                    Text("Welcome back! Your progress was saved.")
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: Spacing.xs) {
                if pendingOperationsCount > 0 {
                    Button {
                        HapticManager.light()
                        onRetryOperations?()
                        dismiss()
                    } label: {
                        Text("Sync")
                            .font(.DesignSystem.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.DesignSystem.brandGreen)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(Color.DesignSystem.brandGreen.opacity(0.15)),
                            )
                    }
                }

                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .frame(width: 28.0, height: 28)
                        .background(
                            Circle()
                                .fill(Color.DesignSystem.textSecondary.opacity(0.1)),
                        )
                }
            }
        }
    }

    private var glassBackground: some View {
        ZStack {
            // Base glass
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            // Gradient overlay
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )

            // Border
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                )
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                if value.translation.height < -20 {
                    dismiss()
                }
            }
    }

    // MARK: - Animations

    private func animateIn() {
        guard !reduceMotion else {
            opacity = 1
            offsetY = 0
            glowIntensity = 0.5
            return
        }

        // Icon spin animation
        withAnimation(.interpolatingSpring(stiffness: 100, damping: 8).delay(0.2)) {
            iconRotation = 360
        }

        // Slide in
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            opacity = 1
            offsetY = 0
        }

        // Glow pulse
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 20).delay(0.3)) {
            glowIntensity = 0.6
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(1.1)) {
            glowIntensity = 0.3
        }
    }

    private func dismiss() {
        guard isVisible else { return }

        if reduceMotion {
            isVisible = false
            onDismiss?()
            return
        }

        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            opacity = 0
            offsetY = -100
        }

        Task { @MainActor in
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(300 * 1_000_000))
            #else
            try? await Task.sleep(for: .milliseconds(300))
            #endif
            isVisible = false
            onDismiss?()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        GlassRecoveryBanner(
            isVisible: .constant(true),
            pendingOperationsCount: 3,
            onDismiss: { print("Dismissed") },
            onRetryOperations: { print("Retry") },
        )
    }
}

#Preview("No Pending") {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        GlassRecoveryBanner(
            isVisible: .constant(true),
            pendingOperationsCount: 0,
        )
    }
}

#endif
