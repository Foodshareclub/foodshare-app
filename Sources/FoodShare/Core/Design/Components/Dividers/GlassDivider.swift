//
//  GlassDivider.swift
//  Foodshare
//
//  Liquid Glass v26 Divider Component
//


#if !SKIP
import SwiftUI

struct GlassDivider: View {
    let style: DividerStyle

    enum DividerStyle {
        case horizontal
        case vertical
        case gradient
        case dotted
    }

    init(style: DividerStyle = .horizontal) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .horizontal:
            Rectangle()
                .fill(Color.DesignSystem.glassBorder)
                .frame(height: 1.0)

        case .vertical:
            Rectangle()
                .fill(Color.DesignSystem.glassBorder)
                .frame(width: 1.0)

        case .gradient:
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.DesignSystem.glassBorder,
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .frame(height: 1.0)

        case .dotted:
            HStack(spacing: Spacing.xs) {
                ForEach(0 ..< 20, id: \.self) { _ in
                    Circle()
                        .fill(Color.DesignSystem.glassBorder)
                        .frame(width: 2.0, height: 2)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        VStack(spacing: Spacing.md) {
            Text("Horizontal")
            GlassDivider(style: .horizontal)
        }

        VStack(spacing: Spacing.md) {
            Text("Gradient")
            GlassDivider(style: .gradient)
        }

        VStack(spacing: Spacing.md) {
            Text("Dotted")
            GlassDivider(style: .dotted)
        }

        HStack(spacing: Spacing.md) {
            Text("Vertical")
            GlassDivider(style: .vertical)
                .frame(height: 50.0)
            Text("Divider")
        }
    }
    .padding()
    .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
}

#endif
