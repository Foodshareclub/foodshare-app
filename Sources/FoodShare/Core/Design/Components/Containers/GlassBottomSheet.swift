//
//  GlassBottomSheet.swift
//  Foodshare
//
//  Liquid Glass v26 Bottom Sheet with animated mesh gradient
//  Premium component with drag gesture, rubber-band effect, and multiple detents
//


#if !SKIP
import SwiftUI

// MARK: - Glass Bottom Sheet

struct GlassBottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let detents: [SheetDetent]
    let showDragIndicator: Bool
    let onDismiss: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var currentDetent: SheetDetent = .medium
    @State private var dragOffset: CGFloat = 0
    #if !SKIP
    @GestureState private var isDragging = false
    #else
    @State private var isDragging = false
    #endif

    init(
        isPresented: Binding<Bool>,
        detents: [SheetDetent] = [.medium, .large],
        showDragIndicator: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.detents = detents.isEmpty ? [.medium] : detents
        self.showDragIndicator = showDragIndicator
        self.onDismiss = onDismiss
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let sheetHeight = currentDetent.height(for: screenHeight)
            let yOffset = isPresented ? (screenHeight - sheetHeight + dragOffset) : screenHeight

            ZStack(alignment: .bottom) {
                // Dimmed background
                if isPresented {
                    Color.black
                        .opacity(backgroundOpacity(screenHeight: screenHeight, sheetHeight: sheetHeight))
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissSheet()
                        }
                        .transition(.opacity)
                }

                // Sheet content
                VStack(spacing: 0) {
                    if showDragIndicator {
                        dragIndicator
                    }

                    content()
                        .frame(maxWidth: .infinity)
                }
                .frame(height: maxSheetHeight(for: screenHeight), alignment: .top)
                .background(sheetBackground)
                .clipShape(
                    RoundedCornerShape(
                        corners: [UIRectCorner.topLeft, UIRectCorner.topRight],
                        radius: CornerRadius.xl
                    )
                )
                .overlay(alignment: .top) {
                    RoundedCornerShape(corners: [UIRectCorner.topLeft, UIRectCorner.topRight], radius: CornerRadius.xl)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.glassHighlight,
                                    Color.DesignSystem.glassBorder.opacity(0.5),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(height: sheetHeight)
                }
                .shadow(color: Color.black.opacity(0.2), radius: 30, y: -10)
                .offset(y: yOffset)
                .gesture(dragGesture(screenHeight: screenHeight))
            }
            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: isPresented)
            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: currentDetent)
        }
        .ignoresSafeArea()
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.DesignSystem.textTertiary)
                .frame(width: 36.0, height: 5)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.md)
        }
    }

    // MARK: - Sheet Background

    private var sheetBackground: some View {
        ZStack {
            // Ultra thin material
            Rectangle()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            // Gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.clear,
                    Color.black.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Drag Gesture

    private func dragGesture(screenHeight: CGFloat) -> some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                let translation = value.translation.height

                // Rubber band effect when dragging beyond bounds
                if translation < 0 {
                    // Dragging up - rubber band
                    dragOffset = translation * 0.3
                } else {
                    // Dragging down - normal
                    dragOffset = translation
                }
            }
            .onEnded { value in
                let translation = value.translation.height
                let velocity = value.predictedEndTranslation.height - translation

                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    dragOffset = 0

                    // Determine action based on velocity and position
                    if translation > 100 || velocity > 500 {
                        // Dismiss or go to smaller detent
                        if let smallerDetent = nextSmallerDetent() {
                            currentDetent = smallerDetent
                        } else {
                            dismissSheet()
                        }
                    } else if translation < -50 || velocity < -500 {
                        // Go to larger detent
                        if let largerDetent = nextLargerDetent() {
                            currentDetent = largerDetent
                        }
                    }
                }
            }
    }

    // MARK: - Helpers

    private func backgroundOpacity(screenHeight: CGFloat, sheetHeight: CGFloat) -> Double {
        let baseOpacity = 0.4
        let adjustedOffset = max(0.0, dragOffset)
        let dismissProgress = adjustedOffset / (sheetHeight * 0.5)
        return max(0.0, baseOpacity * (1 - dismissProgress))
    }

    private func maxSheetHeight(for screenHeight: CGFloat) -> CGFloat {
        detents.map { $0.height(for: screenHeight) }.max() ?? screenHeight * 0.5
    }

    private func nextSmallerDetent() -> SheetDetent? {
        let sortedDetents = detents.sorted { $0.rawValue < $1.rawValue }
        guard let currentIndex = sortedDetents.firstIndex(of: currentDetent),
              currentIndex > 0 else { return nil }
        return sortedDetents[currentIndex - 1]
    }

    private func nextLargerDetent() -> SheetDetent? {
        let sortedDetents = detents.sorted { $0.rawValue < $1.rawValue }
        guard let currentIndex = sortedDetents.firstIndex(of: currentDetent),
              currentIndex < sortedDetents.count - 1 else { return nil }
        return sortedDetents[currentIndex + 1]
    }

    private func dismissSheet() {
        HapticFeedback.light()
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
            isPresented = false
        }
        onDismiss?()
    }
}

// MARK: - Sheet Detent

enum SheetDetent: CGFloat, CaseIterable {
    case small = 0.25
    case medium = 0.5
    case large = 0.85

    func height(for screenHeight: CGFloat) -> CGFloat {
        screenHeight * rawValue
    }
}

// MARK: - Rounded Corner Shape

struct RoundedCornerShape: Shape {
    let corners: UIRectCorner
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Extension for Bottom Sheet

extension View {
    func glassBottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: [SheetDetent] = [.medium, .large],
        showDragIndicator: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self

            GlassBottomSheet(
                isPresented: isPresented,
                detents: detents,
                showDragIndicator: showDragIndicator,
                onDismiss: onDismiss,
                content: content
            )
        }
    }
}

// MARK: - Previews

#Preview("Basic Sheet") {
    @Previewable @State var isPresented = true

    ZStack {
        LinearGradient(
            colors: [Color.DesignSystem.accentBlue.opacity(0.3), Color.DesignSystem.accentCyan.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        Button("Show Sheet") {
            isPresented = true
        }
        .buttonStyle(.borderedProminent)

        GlassBottomSheet(isPresented: $isPresented) {
            VStack(spacing: Spacing.lg) {
                Text("Glass Bottom Sheet")
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)

                Text("Drag to resize or dismiss")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)

                ForEach(0..<5) { index in
                    HStack {
                        Circle()
                            .fill(Color.DesignSystem.accentBlue.opacity(0.3))
                            .frame(width: 44.0, height: 44)

                        VStack(alignment: .leading) {
                            Text("Item \(index + 1)")
                                .font(.DesignSystem.bodyMedium)
                            Text("Description text")
                                .font(.DesignSystem.caption)
                                .foregroundColor(.DesignSystem.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                }

                Spacer()
            }
            .padding(.top, Spacing.md)
        }
    }
}

#Preview("Multiple Detents") {
    @Previewable @State var isPresented = true

    Color.DesignSystem.background
        .ignoresSafeArea()
        .glassBottomSheet(
            isPresented: $isPresented,
            detents: [.small, .medium, .large]
        ) {
            VStack(spacing: Spacing.md) {
                Text("Resize Me")
                    .font(.DesignSystem.headlineSmall)

                Text("Small • Medium • Large")
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()
            }
            .padding()
        }
}

#endif
