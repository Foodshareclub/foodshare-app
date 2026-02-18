//
//  SkeletonView.swift
//  Foodshare
//
//  Skeleton loading states for smooth UX
//


#if !SKIP
import SwiftUI

// MARK: - Skeleton Modifier

struct SkeletonModifier: ViewModifier {
    let isLoading: Bool

    @State private var opacity = 0.3

    func body(content: Content) -> some View {
        if isLoading {
            content
                .redacted(reason: .placeholder)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.sm)
                        .fill(Color.DesignSystem.glassBackground)
                        .opacity(opacity),
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        opacity = 0.6
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func skeleton(isLoading: Bool) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading))
    }
}

// MARK: - Basic Skeleton View

struct SkeletonView: View {
    @State private var opacity = 0.3

    var body: some View {
        Rectangle()
            .fill(Color.DesignSystem.glassBackground)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    opacity = 0.6
                }
            }
    }
}

// MARK: - Skeleton Shapes

struct SkeletonLine: View {
    var width: CGFloat?
    var height: CGFloat = 16

    @State private var opacity = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.DesignSystem.glassBackground)
            .frame(width: width, height: height)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    opacity = 0.6
                }
            }
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40

    @State private var opacity = 0.3

    var body: some View {
        Circle()
            .fill(Color.DesignSystem.glassBackground)
            .frame(width: size, height: size)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    opacity = 0.6
                }
            }
    }
}

struct SkeletonRect: View {
    var width: CGFloat?
    var height: CGFloat = 100
    var cornerRadius: CGFloat = Spacing.sm

    @State private var opacity = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.DesignSystem.glassBackground)
            .frame(width: width, height: height)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    opacity = 0.6
                }
            }
    }
}

// MARK: - Skeleton Card

struct SkeletonFoodCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SkeletonRect(height: 150, cornerRadius: Spacing.md)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                SkeletonLine(width: 180, height: 20)
                SkeletonLine(width: 120, height: 14)

                HStack {
                    SkeletonLine(width: 60, height: 12)
                    Spacer()
                    SkeletonLine(width: 40, height: 12)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
        }
        .glassBackground()
    }
}

struct SkeletonRoomRow: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            SkeletonCircle(size: 50)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                SkeletonLine(width: 120, height: 16)
                SkeletonLine(width: 200, height: 14)
            }

            Spacer()

            SkeletonLine(width: 40, height: 12)
        }
        .padding(Spacing.md)
    }
}

struct SkeletonProfileHeader: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            SkeletonCircle(size: 80)
            SkeletonLine(width: 120, height: 20)
            SkeletonLine(width: 80, height: 14)

            HStack(spacing: Spacing.lg) {
                VStack {
                    SkeletonLine(width: 30, height: 20)
                    SkeletonLine(width: 50, height: 12)
                }
                VStack {
                    SkeletonLine(width: 30, height: 20)
                    SkeletonLine(width: 50, height: 12)
                }
                VStack {
                    SkeletonLine(width: 30, height: 20)
                    SkeletonLine(width: 50, height: 12)
                }
            }
        }
        .padding(Spacing.lg)
        .glassBackground()
    }
}

// MARK: - Skeleton List

struct SkeletonList<Content: View>: View {
    let count: Int
    let content: () -> Content

    init(count: Int = 5, @ViewBuilder content: @escaping () -> Content) {
        self.count = count
        self.content = content
    }

    var body: some View {
        ForEach(0 ..< count, id: \.self) { _ in
            content()
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        ScrollView {
            VStack(spacing: Spacing.md) {
                SkeletonFoodCard()
                SkeletonFoodCard()
                SkeletonRoomRow()
                SkeletonProfileHeader()
            }
            .padding()
        }
        .background(Color.backgroundGradient)
    }
#endif

#endif
