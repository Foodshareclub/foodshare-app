//
//  GlassStepper.swift
//  Foodshare
//
//  Liquid Glass v26 Stepper Component with ProMotion-optimized animations
//


#if !SKIP
import SwiftUI

// MARK: - Glass Stepper

struct GlassStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let label: String?
    let icon: String?
    let valueFormatter: (Int) -> String

    @State private var isPlusPressed = false
    @State private var isMinusPressed = false

    init(
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        label: String? = nil,
        icon: String? = nil,
        valueFormatter: @escaping (Int) -> String = { "\($0)" },
    ) {
        _value = value
        self.range = range
        self.step = step
        self.label = label
        self.icon = icon
        self.valueFormatter = valueFormatter
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            labelSection
            stepperControls
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.white.opacity(0.04))
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
    }

    @ViewBuilder
    private var labelSection: some View {
        if icon != nil || label != nil {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                }
                if let label {
                    Text(label)
                        .font(.DesignSystem.labelLarge)
                        .foregroundStyle(Color.DesignSystem.text)
                }
            }
            Spacer()
        }
    }

    private var stepperControls: some View {
        HStack(spacing: 0) {
            minusButton
            valueDisplay
            plusButton
        }
        .padding(Spacing.xxxs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.white.opacity(0.06))
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.white.opacity(0.1), lineWidth: 1),
        )
    }

    private var minusButton: some View {
        Button {
            decrement()
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    canDecrement
                        ? Color.DesignSystem.text
                        : Color.DesignSystem.textTertiary,
                )
                .frame(width: 44.0, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.white.opacity(isMinusPressed ? 0.15 : 0.08)),
                )
                .scaleEffect(isMinusPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!canDecrement)
        #if !SKIP
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isMinusPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isMinusPressed = false
                    }
                },
        )
        #endif
    }

    private var valueDisplay: some View {
        Text(valueFormatter(value))
            .font(.DesignSystem.headlineSmall)
            .foregroundStyle(Color.DesignSystem.text)
            .frame(minWidth: 60)
            #if !SKIP
            .contentTransition(.numericText())
            #endif
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: value)
    }

    private var plusButton: some View {
        Button {
            increment()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    canIncrement
                        ? Color.DesignSystem.text
                        : Color.DesignSystem.textTertiary,
                )
                .frame(width: 44.0, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.white.opacity(isPlusPressed ? 0.15 : 0.08)),
                )
                .scaleEffect(isPlusPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!canIncrement)
        #if !SKIP
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isPlusPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isPlusPressed = false
                    }
                },
        )
        #endif
    }

    // MARK: - Computed Properties

    private var canIncrement: Bool {
        value + step <= range.upperBound
    }

    private var canDecrement: Bool {
        value - step >= range.lowerBound
    }

    // MARK: - Actions

    private func increment() {
        guard canIncrement else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            value += step
        }
        HapticManager.selection()
    }

    private func decrement() {
        guard canDecrement else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            value -= step
        }
        HapticManager.selection()
    }
}

// MARK: - Compact Glass Stepper

struct GlassCompactStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let accentColor: Color

    @State private var isPlusPressed = false
    @State private var isMinusPressed = false

    init(
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        accentColor: Color = .DesignSystem.brandGreen,
    ) {
        _value = value
        self.range = range
        self.step = step
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            // Minus button
            Button {
                decrement()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canDecrement ? Color.DesignSystem.text : Color.DesignSystem.textTertiary)
                    .frame(width: 32.0, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isMinusPressed ? 0.15 : 0.08)),
                    )
                    .scaleEffect(isMinusPressed ? 0.9 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)
            #if !SKIP
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isMinusPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isMinusPressed = false
                        }
                    },
            )
            #endif

            // Value
            Text("\(value)")
                .font(.DesignSystem.labelLarge)
                .foregroundStyle(Color.DesignSystem.text)
                .frame(minWidth: 32)
                #if !SKIP
                .contentTransition(.numericText())
                #endif
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: value)

            // Plus button
            Button {
                increment()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canIncrement ? Color.DesignSystem.text : Color.DesignSystem.textTertiary)
                    .frame(width: 32.0, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isPlusPressed ? 0.15 : 0.08)),
                    )
                    .scaleEffect(isPlusPressed ? 0.9 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(!canIncrement)
            #if !SKIP
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isPlusPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isPlusPressed = false
                        }
                    },
            )
            #endif
        }
        .padding(Spacing.xxxs)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1),
        )
    }

    // MARK: - Computed Properties

    private var canIncrement: Bool {
        value + step <= range.upperBound
    }

    private var canDecrement: Bool {
        value - step >= range.lowerBound
    }

    // MARK: - Actions

    private func increment() {
        guard canIncrement else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            value += step
        }
        HapticManager.selection()
    }

    private func decrement() {
        guard canDecrement else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            value -= step
        }
        HapticManager.selection()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            GlassStepper(
                value: .constant(5),
                in: 1 ... 10,
                label: "Quantity",
                icon: "number",
            )

            GlassStepper(
                value: .constant(30),
                in: 15 ... 120,
                step: 15,
                label: "Duration",
                icon: "clock.fill",
                valueFormatter: { "\($0) min" },
            )

            HStack {
                Text("Servings:")
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                GlassCompactStepper(
                    value: .constant(2),
                    in: 1 ... 8,
                )
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.white.opacity(0.04))
                    #if !SKIP
                    .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .background(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
        .padding()
    }
}

#endif
