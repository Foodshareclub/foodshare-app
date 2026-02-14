//
//  GlassImageViewer.swift
//  Foodshare
//
//  Liquid Glass v27 Full-screen Image Viewer
//  Premium component with pinch-to-zoom, swipe navigation, parallax effects
//  Optimized for ProMotion 120Hz displays with interpolating spring animations
//

import Kingfisher
import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Image Viewer

struct GlassImageViewer: View {
    let images: [URL]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isDragging = false

    @GestureState private var magnifyBy: CGFloat = 1.0

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with blur
                backgroundLayer

                // Image carousel
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                        zoomableImage(url: url, geometry: geometry)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Overlay controls
                VStack {
                    topBar
                    Spacer()
                    bottomBar(geometry: geometry)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .transition(.opacity)
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        ZStack {
            Color.black.opacity(0.95)

            // Subtle gradient overlay
            RadialGradient(
                colors: [
                    Color.DesignSystem.accentBlue.opacity(0.1),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Zoomable Image

    private func zoomableImage(url: URL, geometry: GeometryProxy) -> some View {
        KFImage(url)
            .placeholder {
                ZStack {
                    Color.DesignSystem.glassBackground
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale * magnifyBy)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .updating($magnifyBy) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            let newScale = lastScale * value
                            scale = min(maxScale, max(minScale, newScale))
                            lastScale = scale

                            // Reset offset if zoomed out
                            if scale <= minScale {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        },
                    DragGesture()
                        .onChanged { value in
                            if scale > minScale {
                                isDragging = true
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            lastOffset = offset

                            // Dismiss if dragged down while not zoomed
                            if scale <= minScale && value.translation.height > 100 {
                                dismissViewer()
                            }
                        }
                )
            )
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                            if scale > minScale {
                                // Reset zoom
                                scale = minScale
                                lastScale = minScale
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                // Zoom in
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                        HapticManager.light()
                    }
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close button
            Button {
                dismissViewer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            }
            .buttonStyle(ImageViewerButtonStyle())

            Spacer()

            // Image counter with animated number transition
            Text("\(selectedIndex + 1) / \(images.count)")
                .font(.DesignSystem.labelMedium)
                .foregroundColor(.white.opacity(0.8))
                .contentTransition(.numericText())
                .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: selectedIndex)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )

            Spacer()

            // Share button
            Button {
                HapticManager.light()
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            }
            .buttonStyle(ImageViewerButtonStyle())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .drawingGroup() // GPU rasterization for top bar
    }

    // MARK: - Bottom Bar

    private func bottomBar(geometry: GeometryProxy) -> some View {
        VStack(spacing: Spacing.md) {
            // Thumbnail strip (if multiple images)
            if images.count > 1 {
                thumbnailStrip
            }

            // Page indicator
            GlassPageIndicator(
                numberOfPages: images.count,
                currentPage: selectedIndex
            )
        }
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Thumbnail Strip

    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                        thumbnailButton(url: url, index: index)
                            .id(index)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(height: 60)
    }

    private func thumbnailButton(url: URL, index: Int) -> some View {
        Button {
            HapticManager.light()
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                selectedIndex = index
                // Reset zoom when switching images
                scale = minScale
                lastScale = minScale
                offset = .zero
                lastOffset = .zero
            }
        } label: {
            KFImage(url)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(
                            selectedIndex == index
                                ? Color.white
                                : Color.white.opacity(0.3),
                            lineWidth: selectedIndex == index ? 2 : 1
                        )
                )
                .scaleEffect(selectedIndex == index ? 1.1 : 1.0)
                .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: selectedIndex)
        }
        .drawingGroup() // GPU rasterization for smooth thumbnail rendering
    }

    // MARK: - Helpers

    private func dismissViewer() {
        HapticManager.light()
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            isPresented = false
        }
    }
}

// MARK: - Glass Page Indicator

struct GlassPageIndicator: View {
    let numberOfPages: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentPage
                            ? Color.white
                            : Color.white.opacity(0.4)
                    )
                    .frame(
                        width: index == currentPage ? 8 : 6,
                        height: index == currentPage ? 8 : 6
                    )
                    .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: currentPage)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .drawingGroup() // GPU rasterization for indicator animations
    }
}

// MARK: - Image Viewer Button Style

private struct ImageViewerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 25), value: configuration.isPressed)
    }
}

// MARK: - View Extension

extension View {
    func glassImageViewer(
        images: [URL],
        selectedIndex: Binding<Int>,
        isPresented: Binding<Bool>
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            GlassImageViewer(
                images: images,
                selectedIndex: selectedIndex,
                isPresented: isPresented
            )
            .background(Color.clear)
        }
    }
}

// MARK: - Previews

#Preview("Image Viewer") {
    @Previewable @State var selectedIndex = 0
    @Previewable @State var isPresented = true

    let sampleImages = [
        URL(string: "https://picsum.photos/800/600?random=1")!,
        URL(string: "https://picsum.photos/800/600?random=2")!,
        URL(string: "https://picsum.photos/800/600?random=3")!,
        URL(string: "https://picsum.photos/800/600?random=4")!
    ]

    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        if isPresented {
            GlassImageViewer(
                images: sampleImages,
                selectedIndex: $selectedIndex,
                isPresented: $isPresented
            )
        } else {
            Button("Show Viewer") {
                isPresented = true
            }
        }
    }
}

#Preview("Single Image") {
    @Previewable @State var selectedIndex = 0
    @Previewable @State var isPresented = true

    GlassImageViewer(
        images: [URL(string: "https://picsum.photos/1200/800")!],
        selectedIndex: $selectedIndex,
        isPresented: $isPresented
    )
}
