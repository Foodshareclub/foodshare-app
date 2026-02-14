//
//  GlassProgressBar.swift
//  Foodshare
//
//  Liquid Glass v26 Progress Bar Component with ProMotion-optimized animations
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Progress Bar

struct GlassProgressBar: View {
    let progress: Double
    let height: CGFloat
    let accentColor: Color
    let showPercentage: Bool
    let animated: Bool

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        height: CGFloat = 8,
        accentColor: Color = .DesignSystem.brandGreen,
        showPercentage: Bool = false,
        animated: Bool = true,
    ) {
        self.progress = max(0, min(1, progress))
        self.height = height
        self.accentColor = accentColor
        self.showPercentage = showPercentage
        self.animated = animated
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Progress track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1),
                        )

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    accentColor.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .frame(width: max(height, geometry.size.width * animatedProgress))
                        .shadow(color: accentColor.opacity(0.4), radius: 4, x: 0, y: 0)
                        .overlay(
                            // Shine effect
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom,
                                    ),
                                )
                                .frame(width: max(height, geometry.size.width * animatedProgress)),
                        )
                }
            }
            .frame(height: height)

            // Percentage label
            if showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .frame(width: 40, alignment: .trailing)
                    .contentTransition(.numericText())
            }
        }
        .onAppear {
            if animated {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animatedProgress = progress
                }
            } else {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            if animated {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    animatedProgress = newValue
                }
            } else {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Glass Progress Card

struct GlassProgressCard: View {
    let title: String
    let subtitle: String?
    let progress: Double
    let icon: String?
    let accentColor: Color
    /// Enable GPU rasterization for 120Hz ProMotion performance
    let useGPURasterization: Bool

    init(
        title: String,
        subtitle: String? = nil,
        progress: Double,
        icon: String? = nil,
        accentColor: Color = .DesignSystem.brandGreen,
        useGPURasterization: Bool = false,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.icon = icon
        self.accentColor = accentColor
        self.useGPURasterization = useGPURasterization
    }

    var body: some View {
        let cardContent = VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                // Icon
                if let icon {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.DesignSystem.labelLarge)
                        .foregroundStyle(Color.DesignSystem.text)

                    if let subtitle {
                        Text(subtitle)
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                // Percentage
                Text("\(Int(progress * 100))%")
                    .font(.DesignSystem.headlineSmall)
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
            }

            GlassProgressBar(
                progress: progress,
                height: 10,
                accentColor: accentColor,
            )
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial),
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )

        if useGPURasterization {
            cardContent
                .drawingGroup()
        } else {
            cardContent
        }
    }
}

// MARK: - Glass Circular Progress

struct GlassCircularProgress: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let accentColor: Color
    let showPercentage: Bool

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        size: CGFloat = 80,
        lineWidth: CGFloat = 8,
        accentColor: Color = .DesignSystem.brandGreen,
        showPercentage: Bool = true,
    ) {
        self.progress = max(0, min(1, progress))
        self.size = size
        self.lineWidth = lineWidth
        self.accentColor = accentColor
        self.showPercentage = showPercentage
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    Color.white.opacity(0.1),
                    lineWidth: lineWidth,
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                    ),
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accentColor.opacity(0.3), radius: 4)

            // Center content
            if showPercentage {
                VStack(spacing: 2) {
                    Text("\(Int(animatedProgress * 100))")
                        .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.DesignSystem.text)
                        .contentTransition(.numericText())

                    Text("%")
                        .font(.system(size: size * 0.12, weight: .medium))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Glass Step Progress

struct GlassStepProgress<Item: Identifiable>: View {
    let items: [Item]
    let currentStep: Int
    let accentColor: Color
    let stepLabel: (Item) -> String

    init(
        items: [Item],
        currentStep: Int,
        accentColor: Color = .DesignSystem.brandGreen,
        stepLabel: @escaping (Item) -> String,
    ) {
        self.items = items
        self.currentStep = currentStep
        self.accentColor = accentColor
        self.stepLabel = stepLabel
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 0) {
                    // Step indicator
                    stepIndicator(index: index)

                    // Connector line (not for last item)
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(
                                index < currentStep
                                    ? accentColor
                                    : Color.white.opacity(0.15),
                            )
                            .frame(height: 2)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                    }
                }
            }
        }
    }

    private func stepIndicator(index: Int) -> some View {
        let isCompleted = index < currentStep
        let isCurrent = index == currentStep
        let isPending = index > currentStep

        return ZStack {
            Circle()
                .fill(
                    isCompleted
                        ? accentColor
                        : isCurrent
                            ? accentColor.opacity(0.2)
                            : Color.white.opacity(0.08),
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(
                            isCurrent
                                ? accentColor
                                : Color.white.opacity(isPending ? 0.1 : 0),
                            lineWidth: isCurrent ? 2 : 1,
                        ),
                )
                .shadow(
                    color: isCurrent ? accentColor.opacity(0.3) : Color.clear,
                    radius: 6,
                )

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isCurrent
                            ? accentColor
                            : Color.DesignSystem.textSecondary,
                    )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
    }
}

// MARK: - Glass Upload Progress

struct GlassUploadProgress: View {
    let progress: Double
    let fileName: String
    let fileSize: String?
    let state: UploadState
    let onCancel: (() -> Void)?

    enum UploadState: Equatable {
        case uploading
        case processing
        case completed
        case failed(String)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // File icon with state
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(stateColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                stateIcon
            }

            // File info and progress
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(fileName)
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.text)
                    .lineLimit(1)

                if let fileSize, state != .completed {
                    Text(fileSize)
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                if case .uploading = state {
                    GlassProgressBar(
                        progress: progress,
                        height: 4,
                        accentColor: stateColor,
                        showPercentage: false,
                    )
                } else if case .processing = state {
                    HStack(spacing: Spacing.xxs) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(stateColor)

                        Text("Processing...")
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                } else if case let .failed(error) = state {
                    Text(error)
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(Color.DesignSystem.error)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action button
            if case .uploading = state, let onCancel {
                Button {
                    HapticManager.light()
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
                .buttonStyle(.plain)
            } else if case .completed = state {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.DesignSystem.success)
            } else if case .failed = state {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.DesignSystem.error)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial),
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    stateColor.opacity(0.2),
                    lineWidth: 1,
                ),
        )
    }

    private var stateColor: Color {
        switch state {
        case .uploading, .processing:
            .DesignSystem.brandBlue
        case .completed:
            .DesignSystem.success
        case .failed:
            .DesignSystem.error
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .uploading:
            Image(systemName: "arrow.up.doc.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(stateColor)
        case .processing:
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(stateColor)
                .symbolEffect(.rotate)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(stateColor)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(stateColor)
        }
    }
}

// MARK: - Preview Helper

private struct Step: Identifiable {
    let id = UUID()
    let name: String
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Linear progress bars
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Linear Progress")
                        .font(.DesignSystem.labelMedium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    GlassProgressBar(progress: 0.7)

                    GlassProgressBar(
                        progress: 0.45,
                        accentColor: .DesignSystem.brandBlue,
                        showPercentage: true
                    )

                    GlassProgressBar(
                        progress: 0.9,
                        height: 12,
                        accentColor: .DesignSystem.brandOrange,
                        showPercentage: true,
                    )
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.white.opacity(0.04)),
                )

                // Progress cards
                GlassProgressCard(
                    title: "Daily Challenge",
                    subtitle: "Share 3 items today",
                    progress: 0.66,
                    icon: "trophy.fill",
                    accentColor: .DesignSystem.brandOrange,
                )

                GlassProgressCard(
                    title: "Weekly Goal",
                    subtitle: "Help 10 neighbors this week",
                    progress: 0.4,
                    icon: "heart.fill",
                    accentColor: .DesignSystem.brandPink,
                )

                // Circular progress
                HStack(spacing: Spacing.xl) {
                    GlassCircularProgress(
                        progress: 0.75,
                        size: 100,
                        accentColor: .DesignSystem.brandGreen,
                    )

                    GlassCircularProgress(
                        progress: 0.45,
                        size: 80,
                        lineWidth: 6,
                        accentColor: .DesignSystem.brandBlue,
                    )

                    GlassCircularProgress(
                        progress: 0.9,
                        size: 60,
                        lineWidth: 5,
                        accentColor: .DesignSystem.brandOrange,
                    )
                }

                // Step progress
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Step Progress")
                        .font(.DesignSystem.labelMedium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    GlassStepProgress(
                        items: [
                            Step(name: "Photo"),
                            Step(name: "Details"),
                            Step(name: "Location"),
                            Step(name: "Review")
                        ],
                        currentStep: 2,
                        stepLabel: { $0.name },
                    )
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.white.opacity(0.04)),
                )

                // Upload progress states
                VStack(spacing: Spacing.sm) {
                    GlassUploadProgress(
                        progress: 0.65,
                        fileName: "food_photo.jpg",
                        fileSize: "2.4 MB",
                        state: .uploading,
                        onCancel: {},
                    )

                    GlassUploadProgress(
                        progress: 1.0,
                        fileName: "listing_image.png",
                        fileSize: "1.2 MB",
                        state: .processing,
                        onCancel: nil,
                    )

                    GlassUploadProgress(
                        progress: 1.0,
                        fileName: "avatar.jpg",
                        fileSize: nil,
                        state: .completed,
                        onCancel: nil,
                    )

                    GlassUploadProgress(
                        progress: 0,
                        fileName: "large_file.zip",
                        fileSize: "50 MB",
                        state: .failed("File size exceeds limit"),
                        onCancel: nil,
                    )
                }
            }
            .padding()
        }
    }
}
