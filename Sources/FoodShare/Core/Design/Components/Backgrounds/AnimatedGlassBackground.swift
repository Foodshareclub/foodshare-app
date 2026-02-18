//
//  AnimatedGlassBackground.swift
//  Foodshare
//
//  Liquid Glass v26 Animated Background with floating orbs
//


#if !SKIP
import SwiftUI

struct AnimatedGlassBackground: View {
    let colors: [Color]
    let orbCount: Int

    @State private var positions: [CGPoint] = []
    @State private var scales: [CGFloat] = []
    @State private var hasStartedAnimation = false

    init(
        colors: [Color] = [
            Color.DesignSystem.brandGreen,
            Color.DesignSystem.brandBlue,
            Color.DesignSystem.brandOrange
        ],
        orbCount: Int = 3,
    ) {
        self.colors = colors
        self.orbCount = orbCount
    }

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: colors.map { $0.opacity(0.15) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            // Animated orbs
            GeometryReader { geometry in
                ForEach(0 ..< orbCount, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    colors[index % colors.count].opacity(0.3),
                                    colors[index % colors.count].opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200,
                            ),
                        )
                        .frame(width: 300.0, height: 300)
                        .blur(radius: 60)
                        .scaleEffect(scales.indices.contains(index) ? scales[index] : 1.0)
                        .position(
                            positions.indices.contains(index)
                                ? positions[index]
                                : CGPoint(
                                    x: geometry.size.width * CGFloat(index) / CGFloat(orbCount),
                                    y: geometry.size.height * 0.3,
                                ),
                        )
                }
                .onAppear {
                    guard !hasStartedAnimation else { return }
                    hasStartedAnimation = true
                    startAnimation(in: geometry.size)
                }
                .onChange(of: geometry.size) { _, newSize in
                    // Re-animate if size changes significantly (e.g., rotation)
                    if !positions.isEmpty {
                        startAnimation(in: newSize)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private func startAnimation(in size: CGSize) {
        // Initialize random positions and scales
        positions = (0 ..< orbCount).map { _ in
            CGPoint(
                x: CGFloat.random(in: 0 ... size.width),
                y: CGFloat.random(in: 0 ... size.height),
            )
        }

        scales = (0 ..< orbCount).map { _ in
            CGFloat.random(in: 0.8 ... 1.2)
        }

        // Animate continuously
        withAnimation(
            .easeInOut(duration: Double.random(in: 8 ... 12))
                .repeatForever(autoreverses: true),
        ) {
            positions = (0 ..< orbCount).map { _ in
                CGPoint(
                    x: CGFloat.random(in: -100 ... size.width + 100),
                    y: CGFloat.random(in: -100 ... size.height + 100),
                )
            }

            scales = (0 ..< orbCount).map { _ in
                CGFloat.random(in: 0.8 ... 1.2)
            }
        }
    }
}

#Preview {
    AnimatedGlassBackground()
}

#endif
