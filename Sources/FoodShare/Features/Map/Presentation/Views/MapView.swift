//
//  MapView.swift
//  Foodshare
//
//  Interactive map view showing food listings using MapKit
//  Liquid Glass v27 design system with ProMotion 120Hz optimizations
//


#if !SKIP
#if !SKIP
import CoreLocation
#endif
#if !SKIP
import MapKit
#endif
import OSLog
import SwiftUI

#if DEBUG
    import Inject
#endif

private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "MapView")

struct MapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    @State private var viewModel: MapViewModel
    @State private var selectedItem: FoodItem?
    @State private var showItemDetail = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isInitialLoad = true
    @State private var showRadiusOverlay = false
    @State private var searchRadius: CGFloat = 5.0
    @State private var showHeatmap = false
    @State private var showMapControls = true
    @State private var zoomLevel = 0.5
    @State private var selectedCategory: ListingCategory?

    private let zoomLevels: [(name: String, delta: Double)] = [
        ("Global", 120.0),
        ("Continent", 40.0),
        ("Country", 15.0),
        ("Region", 5.0),
        ("City", 0.5),
        ("Neighborhood", 0.1),
        ("Block", 0.02),
        ("Street", 0.005),
    ]

    init(feedRepository: any FeedRepository) {
        self._viewModel = State(initialValue: MapViewModel(feedRepository: feedRepository))
    }

    init(viewModel: MapViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Main map with interactive markers
            Map(position: $cameraPosition, selection: $selectedItem) {
                UserAnnotation()

                ForEach(viewModel.items) { item in
                    if let coordinate = item.coordinate {
                        Annotation(item.postName, coordinate: coordinate) {
                            LiquidGlassMapMarker(
                                item: item,
                                isSelected: selectedItem?.id == item.id,
                                engagementStatus: viewModel.engagementStatuses[item.id],
                                onLike: {
                                    Task {
                                        await viewModel.toggleLike(for: item)
                                    }
                                },
                                onBookmark: {
                                    Task {
                                        await viewModel.toggleBookmark(for: item)
                                    }
                                },
                            )
                        }
                        .tag(item)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {}
            .ignoresSafeArea(.all, edges: .top)
            .onMapCameraChange(frequency: .onEnd) { context in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 24)) {
                    viewModel.onMapRegionChanged(context.region)
                }
                Task {
                    await viewModel.loadItems(near: context.region.center)
                }
            }
            .refreshable {
                await viewModel.loadInitialData()
            }

            // MARK: - Map Overlay Controls
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if !viewModel.items.isEmpty {
                        LiquidGlassItemCountBadge(count: viewModel.items.count)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity,
                            ))
                    }

                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)

                Spacer()
            }

            // Right-side unified control panel - premium 3D glass design
            VStack {
                HStack {
                    Spacer()

                    Glass3DMapControlPanel(
                        onZoomIn: zoomIn,
                        onZoomOut: zoomOut,
                        onRecenter: recenterOnUser,
                        showRadiusOverlay: $showRadiusOverlay,
                        showHeatmap: $showHeatmap,
                        isLoading: viewModel.isLoading,
                    )
                    .padding(.trailing, Spacing.md)
                }
                .padding(.top, Spacing.lg)

                Spacer()
            }

            if viewModel.isLoading {
                LiquidGlassLoadingIndicator()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
                cameraPosition = .region(viewModel.region)
            }
        }
        .onChange(of: viewModel.userLocationCoords) { _, newLocation in
            if let location = newLocation {
                withAnimation(.interpolatingSpring(stiffness: 180, damping: 22)) {
                    let region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05),
                    )
                    cameraPosition = .region(region)
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            if newItem != nil {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                showItemDetail = true
            }
        }
        .sheet(isPresented: $showItemDetail) {
            if let item = selectedItem {
                LiquidGlassMapDetailSheet(item: item)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(CornerRadius.xl)
            }
        }
    }

    private func zoomIn() {
        HapticManager.light()
        let currentIndex = currentZoomIndex()
        let newIndex = min(currentIndex + 1, zoomLevels.count - 1)
        applyZoom(index: newIndex)
    }

    private func zoomOut() {
        HapticManager.light()
        let currentIndex = currentZoomIndex()
        let newIndex = max(currentIndex - 1, 0)
        applyZoom(index: newIndex)
    }

    private func currentZoomIndex() -> Int {
        let currentDelta = currentRegion?.span.latitudeDelta ?? 0.5

        var closestIndex = 0
        var closestDiff = Double.infinity
        for (index, level) in zoomLevels.enumerated() {
            let diff = abs(level.delta - currentDelta)
            if diff < closestDiff {
                closestDiff = diff
                closestIndex = index
            }
        }
        return closestIndex
    }

    private func applyZoom(index: Int) {
        let level = zoomLevels[index]
        let center = currentRegion?.center ?? .defaultFallback

        withAnimation(.interpolatingSpring(stiffness: 200, damping: 20)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: level.delta, longitudeDelta: level.delta),
            ))
        }
    }

    private var currentRegion: MKCoordinateRegion? {
        MKCoordinateRegion(
            center: viewModel.region.center,
            span: viewModel.region.span,
        )
    }

    private func recenterOnUser() {
        HapticManager.medium()
        Task {
            await viewModel.recenterOnUser()
            if let userLocation = viewModel.userLocation {
                withAnimation(.interpolatingSpring(stiffness: 180, damping: 22)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05),
                    ))
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Premium 3D Glass Map Control Panel

struct Glass3DMapControlPanel: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onRecenter: () -> Void
    @Binding var showRadiusOverlay: Bool
    @Binding var showHeatmap: Bool
    var isLoading = false

    private let buttonSize: CGFloat = 44
    private let containerWidth: CGFloat = 48

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Zoom control group
            Glass3DControlGroup {
                VStack(spacing: 0) {
                    Glass3DButton(icon: "plus", size: buttonSize, action: onZoomIn)
                    Glass3DDivider()
                    Glass3DButton(icon: "minus", size: buttonSize, action: onZoomOut)
                }
            }
            .frame(width: containerWidth)

            // Location button
            Glass3DControlGroup {
                Glass3DButton(icon: "location.fill", size: buttonSize, action: onRecenter)
            }
            .frame(width: containerWidth)

            // Toggle buttons group
            Glass3DControlGroup {
                VStack(spacing: 0) {
                    Glass3DButton(
                        icon: showRadiusOverlay ? "circle.dashed.inset.filled" : "circle.dashed",
                        size: buttonSize,
                        isActive: showRadiusOverlay,
                    ) {
                        showRadiusOverlay.toggle()
                    }
                    Glass3DDivider()
                    Glass3DButton(
                        icon: showHeatmap ? "flame.fill" : "flame",
                        size: buttonSize,
                        isActive: showHeatmap,
                    ) {
                        showHeatmap.toggle()
                    }
                }
            }
            .frame(width: containerWidth)
        }
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

// MARK: - 3D Control Group Container

struct Glass3DControlGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        #if !SKIP
                        .fill(.ultraThinMaterial)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif

                    // Inner highlight (3D effect)
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.05), .clear],
                                startPoint: .top,
                                endPoint: .bottom,
                            ),
                        )
                        .padding(1)
                        .mask(RoundedRectangle(cornerRadius: CornerRadius.large))
                },
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1),
                                Color.DesignSystem.glassBorder.opacity(0.3),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 0.5,
                    ),
            )
            // 3D shadow stack
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }
}

// MARK: - 3D Button

struct Glass3DButton: View {
    let icon: String
    var size: CGFloat = 44
    var isActive = false
    let action: () -> Void

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: isActive
                ? [Color.DesignSystem.brandGreen, Color.DesignSystem.brandTeal]
                : [Color.DesignSystem.brandGreen.opacity(0.9), Color.DesignSystem.brandTeal.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Active state glow
                if isActive {
                    Circle()
                        .fill(Color.DesignSystem.brandGreen.opacity(0.2))
                        .frame(width: size - 4, height: size - 4)
                        .blur(radius: 3)
                }

                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(iconGradient)
                    .frame(width: size, height: size)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(Glass3DButtonStyle())
        .frame(width: size, height: size)
    }
}

// MARK: - 3D Button Style

struct Glass3DButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 15), value: configuration.isPressed)
    }
}

// MARK: - 3D Divider

struct Glass3DDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.DesignSystem.glassBorder.opacity(0.4))
            .frame(width: 28.0, height: 0.5)
    }
}

// MARK: - Liquid Glass Item Count Badge

struct LiquidGlassItemCountBadge: View {
    let count: Int
    @Environment(\.translationService) private var t

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandTeal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                #if !SKIP
                .symbolEffect(.pulse.byLayer, options: .repeating)
                #endif

            Text("\(count) items nearby")
                .font(.DesignSystem.bodySmall)
                .fontWeight(.medium)
                .foregroundColor(.DesignSystem.text)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        #if !SKIP
        .background(.ultraThinMaterial)
        #else
        .background(Color.DesignSystem.glassSurface.opacity(0.15))
        #endif
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.DesignSystem.glassBorder, Color.DesignSystem.brandGreen.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Liquid Glass Map Marker

struct LiquidGlassMapMarker: View {
    let item: FoodItem
    let isSelected: Bool
    let engagementStatus: PostEngagementStatus?
    let onLike: () -> Void
    let onBookmark: () -> Void

    private var category: ListingCategory {
        ListingCategory(rawValue: item.postType) ?? .food
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Outer glow
                if isSelected {
                    Circle()
                        .fill(category.color.opacity(0.3))
                        .frame(width: 56.0, height: 56)
                        .blur(radius: 8)
                }

                // Glass background
                Circle()
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .frame(width: 48.0, height: 48)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected
                                    ? LinearGradient(
                                        colors: [category.color, category.color.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color.DesignSystem.glassBorder,
                                            Color.DesignSystem.glassBorder.opacity(0.5),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                lineWidth: isSelected ? 2.5 : 1.5,
                            ),
                    )
                    .shadow(
                        color: isSelected ? category.color.opacity(0.4) : .black.opacity(0.15),
                        radius: isSelected ? 12 : 6,
                        y: isSelected ? 4 : 2,
                    )

                // Category icon
                Image(systemName: category.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [category.color, category.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ))
                            : AnyShapeStyle(Color.DesignSystem.text),
                    )
                    #if !SKIP
                    .symbolEffect(.bounce, value: isSelected)
                    #endif
            }

            // Pointer
            LiquidGlassMarkerPointer(isSelected: isSelected, color: category.color)
                .offset(y: -4)

            // Engagement buttons (only when selected)
            if isSelected {
                HStack(spacing: 8) {
                    Button(action: onLike) {
                        Image(systemName: engagementStatus?.isLiked == true ? "heart.fill" : "heart")
                            .foregroundColor(engagementStatus?.isLiked == true ? .red : .gray)
                            .font(.system(size: 12))
                    }
                    Button(action: onBookmark) {
                        Image(systemName: engagementStatus?.isBookmarked == true ? "bookmark.fill" : "bookmark")
                            .foregroundColor(engagementStatus?.isBookmarked == true ? .blue : .gray)
                            .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                #if !SKIP
                .background(.ultraThinMaterial, in: Capsule())
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .transition(.scale.combined(with: .opacity))
                .offset(y: 4)
            }
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Liquid Glass Marker Pointer

struct LiquidGlassMarkerPointer: View {
    let isSelected: Bool
    let color: Color

    var body: some View {
        ZStack {
            if isSelected {
                Triangle()
                    .fill(color.opacity(0.4))
                    .frame(width: 16.0, height: 10)
                    .blur(radius: 4)
            }
            Triangle()
                #if !SKIP
                .fill(.ultraThinMaterial)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .frame(width: 14.0, height: 9)
                .overlay(
                    Triangle()
                        .stroke(isSelected ? color.opacity(0.8) : Color.DesignSystem.glassBorder, lineWidth: 1),
                )
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Liquid Glass Loading Indicator

struct LiquidGlassLoadingIndicator: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading nearby food...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(Spacing.lg)
        .background {
            #if !SKIP
            RoundedRectangle(cornerRadius: CornerRadius.large).fill(.ultraThinMaterial)
            #else
            Color.DesignSystem.glassSurface.opacity(0.15)
            #endif
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Liquid Glass Map Detail Sheet

struct LiquidGlassMapDetailSheet: View {
    let item: FoodItem
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex = 0
    @State private var isLiked = false
    @State private var likeCount = 0

    private var category: ListingCategory {
        ListingCategory(rawValue: item.postType) ?? .food
    }

    /// Filter valid image URLs (exclude placeholder images)
    private var validImages: [String] {
        (item.images ?? []).filter { url in
            !url.isEmpty &&
                !url.contains("add_pics") &&
                !url.contains("placeholder")
        }
    }

    /// Check if pickup time has meaningful content
    private var hasValidPickupTime: Bool {
        guard let pickupTime = item.pickupTime else { return false }
        let trimmed = pickupTime.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "-" && trimmed != "–" && trimmed.lowercased() != "n/a"
    }

    /// Check if description has meaningful content
    private var hasValidDescription: Bool {
        guard let desc = cleanedDescription else { return false }
        return !desc.isEmpty && desc.count > 2
    }

    /// Clean description by removing metadata markers like [DESCRIPTION], [SOURCE], etc.
    private var cleanedDescription: String? {
        guard let desc = item.description else { return nil }

        var cleaned = desc

        // Remove common metadata markers and imported content patterns
        let patterns = [
            "\\[DESCRIPTION\\]\\s*",
            "\\[SOURCE\\]\\s*",
            "\\[INFO\\]\\s*",
            "\\[NOTES\\]\\s*",
            "\\[DATA\\]\\s*",
            "\\[DETAILS\\]\\s*",
            "Imported from OpenStreetMap[^.]*\\.",
            "Imported from OSM[^.]*\\.",
            "Source: OpenStreetMap.*",
            "Source: OSM.*",
            "\\(ID:\\s*node/\\d+\\)",
            "\\(node/\\d+\\)",
            "OSM ID:?\\s*node/\\d+",
            "OpenStreetMap ID:?\\s*\\d+",
            "Node ID:?\\s*\\d+",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: "",
                )
            }
        }

        // Clean up extra whitespace, newlines, and multiple spaces
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: String.CompareOptions.regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\n+", with: "\n", options: String.CompareOptions.regularExpression)

        return cleaned.isEmpty ? nil : cleaned
    }

    /// Extract source information if available
    private var sourceInfo: String? {
        guard let desc = item.description else { return nil }

        // Check for OpenStreetMap source
        if desc.contains("OpenStreetMap") || desc.contains("osm") {
            return t.t("map.source.openstreetmap")
        }

        // Check for [SOURCE] marker
        if let range = desc.range(of: "\\[SOURCE\\]\\s*([^\\[]+)", options: String.CompareOptions.regularExpression) {
            let sourceText = String(desc[range])
                .replacingOccurrences(of: "[SOURCE]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return sourceText.isEmpty ? nil : sourceText
        }

        return nil
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Hero Image Section
                if !validImages.isEmpty {
                    ZStack(alignment: .bottom) {
                        // Image carousel
                        TabView(selection: $selectedImageIndex) {
                            ForEach(Array(validImages.enumerated()), id: \.offset) { index, imageUrl in
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle()
                                            .fill(Color.DesignSystem.glassBackground)
                                            .overlay(
                                                ProgressView()
                                                    .tint(.DesignSystem.brandGreen),
                                            )
                                    case let .success(image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure:
                                        Rectangle()
                                            .fill(Color.DesignSystem.glassBackground)
                                            .overlay(
                                                VStack(spacing: Spacing.sm) {
                                                    Image(systemName: category.icon)
                                                        .font(.system(size: 48, weight: .light))
                                                        .foregroundStyle(
                                                            LinearGradient(
                                                                colors: [
                                                                    category.color.opacity(0.6),
                                                                    category.color.opacity(0.3),
                                                                ],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing,
                                                            ),
                                                        )
                                                    Text(category.displayName)
                                                        .font(.DesignSystem.caption)
                                                        .foregroundColor(.DesignSystem.textTertiary)
                                                },
                                            )
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 240.0)
                                .clipped()
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 240.0)

                        // Gradient overlay for better depth
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom,
                        )
                        .frame(height: 100.0)

                        // Image indicators (if multiple images)
                        if validImages.count > 1 {
                            HStack(spacing: 6) {
                                ForEach(0 ..< validImages.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == selectedImageIndex ? Color.white : Color.white.opacity(0.4))
                                        .frame(width: 7.0, height: 7)
                                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                        .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: selectedImageIndex)
                                }
                            }
                            .padding(.bottom, Spacing.md)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
                }

                // MARK: - Header Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // Category pill + Status badge row
                    HStack(spacing: Spacing.sm) {
                        // Category pill with enhanced design
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(category.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [category.color, category.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                #if !SKIP
                                .fill(.ultraThinMaterial)
                                #else
                                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                #endif
                                .overlay(
                                    Capsule()
                                        .fill(category.color.opacity(0.15)),
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [category.color.opacity(0.5), category.color.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing,
                                            ),
                                            lineWidth: 1,
                                        ),
                                ),
                        )
                        .shadow(color: category.color.opacity(0.2), radius: 8, y: 2)

                        Spacer()

                        // Status badge
                        StatusBadge(isActive: item.isActive, isArranged: item.isArranged)
                    }

                    // Title - enhanced typography
                    Text(item.postName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.DesignSystem.text, Color.DesignSystem.text.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, validImages.isEmpty ? Spacing.lg : Spacing.md)
                .padding(.bottom, Spacing.sm)

                // MARK: - Info Cards Section
                VStack(spacing: Spacing.sm) {
                    // Location card (always show if available)
                    if let address = item.displayAddress, !address.isEmpty {
                        DetailInfoCard(
                            icon: "mappin.circle.fill",
                            iconColors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                            label: t.t("common.location"),
                            value: address,
                        )
                    }

                    // Pickup time card (only if valid)
                    if hasValidPickupTime, let pickupTime = item.pickupTime {
                        DetailInfoCard(
                            icon: "clock.fill",
                            iconColors: [.DesignSystem.accentOrange, .DesignSystem.accentYellow],
                            label: t.t("listing.detail.pickup"),
                            value: pickupTime,
                        )
                    }

                    // Food status card (for fridges/food banks)
                    if let foodStatus = item.foodStatusDisplay {
                        DetailInfoCard(
                            icon: "leaf.fill",
                            iconColors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                            label: t.t("listing.detail.food_level"),
                            value: foodStatus,
                        )
                    }

                    // Available hours (for fridges/food banks)
                    if let hours = item.availableHours, !hours.isEmpty {
                        DetailInfoCard(
                            icon: "calendar",
                            iconColors: [.DesignSystem.brandBlue, .DesignSystem.accentPurple],
                            label: t.t("listing.detail.hours"),
                            value: hours,
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

                // MARK: - Description Section
                if hasValidDescription, let description = cleanedDescription {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        // Section header
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandTeal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                )
                            Text(t.t("common.about"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.DesignSystem.text)
                                .textCase(.uppercase)
                                .tracking(0.8)
                        }

                        // Description text with better formatting
                        Text(description)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(.DesignSystem.textSecondary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    #if !SKIP
                                    .fill(.ultraThinMaterial)
                                    #else
                                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                                    #endif
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                                            .stroke(Color.DesignSystem.glassBorder.opacity(0.3), lineWidth: 0.5),
                                    ),
                            )

                        // Source attribution (subtle)
                        if let source = sourceInfo {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                Text(source)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.DesignSystem.textTertiary)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                }

                // MARK: - Stats Row
                statsRow
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                // MARK: - Action Buttons
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        // Directions button (primary)
                        ActionButton(
                            icon: "arrow.triangle.turn.up.right.diamond.fill",
                            label: t.t("map.directions"),
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                            isPrimary: true,
                        ) {
                            openDirections()
                        }

                        // Share button (secondary)
                        ActionButton(
                            icon: "square.and.arrow.up",
                            label: t.t("common.share"),
                            colors: [.DesignSystem.brandBlue, .DesignSystem.accentPurple],
                            isPrimary: false,
                        ) {
                            // Share action
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(Color.DesignSystem.background.opacity(0.01)) // For scroll detection
        .task {
            // Record view using dedicated service (handles deduplication)
            await PostViewService.shared.recordView(postId: item.id)

            // Load initial like status
            likeCount = item.postLikeCounter ?? 0
            do {
                let status = try await PostEngagementService.shared.checkLiked(postId: item.id)
                isLiked = status.isLiked
                likeCount = status.likeCount
            } catch {
                // Silently fail - engagement is non-critical
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Spacing.sm) {
            // Views stat
            DetailStatPill(
                icon: "eye.fill",
                value: "\(item.postViews)",
                label: "views",
                color: .DesignSystem.textSecondary,
                backgroundColor: Color.DesignSystem.glassBackground,
            )

            // Likes - interactive
            LikeButton(
                postId: item.id,
                initialLikeCount: likeCount,
                initialIsLiked: isLiked,
                size: .medium,
                showCount: true,
            ) { isLikedNow, count in
                isLiked = isLikedNow
                likeCount = count
            }

            Spacer()

            // Distance stat
            if let distance = item.distanceDisplay {
                DetailStatPill(
                    icon: "location.fill",
                    value: distance,
                    label: nil,
                    color: .DesignSystem.brandBlue,
                    backgroundColor: Color.DesignSystem.brandBlue.opacity(0.12),
                    borderColor: Color.DesignSystem.brandBlue.opacity(0.25),
                )
            }
        }
    }

    private func openDirections() {
        guard let coordinate = item.coordinate else { return }
        let url = URL(string: "maps://?daddr=\(coordinate.latitude),\(coordinate.longitude)")
        if let url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Detail Info Card

private struct DetailInfoCard: View {
    let icon: String
    let iconColors: [Color]
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon circle with enhanced depth
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: iconColors.map { $0.opacity(0.2) },
                            center: .center,
                            startRadius: 0,
                            endRadius: 24,
                        ),
                    )
                    .frame(width: 48.0, height: 48)
                    .blur(radius: 4)

                // Main circle
                Circle()
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: iconColors.map { $0.opacity(0.12) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            ),
                    )
                    .frame(width: 46.0, height: 46)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: iconColors.map { $0.opacity(0.4) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1.5,
                            ),
                    )
                    .shadow(color: iconColors[0].opacity(0.2), radius: 4, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            // Text content with improved spacing
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.DesignSystem.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.DesignSystem.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(.ultraThinMaterial)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.glassBorder.opacity(0.6),
                                    Color.DesignSystem.glassBorder.opacity(0.2),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 0.5,
                        ),
                ),
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    let label: String
    let colors: [Color]
    var isPrimary = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 16 : 15, weight: .semibold))
                Text(label)
                    .font(.system(size: isPrimary ? 16 : 15, weight: .semibold))
            }
            .foregroundColor(isPrimary ? .white : colors[0])
            .frame(maxWidth: .infinity)
            .padding(.vertical, isPrimary ? 16 : 14)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        )
                    } else {
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .stroke(
                                    LinearGradient(
                                        colors: colors.map { $0.opacity(0.5) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                    lineWidth: 2,
                                ),
                        )
                    }
                },
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .shadow(color: colors[0].opacity(isPrimary ? 0.3 : 0.1), radius: isPrimary ? 12 : 6, y: isPrimary ? 4 : 2)
        }
        .buttonStyle(GlassButtonPressStyle())
    }
}

// MARK: - Glass Button Press Style

private struct GlassButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 20), value: configuration.isPressed)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let isActive: Bool
    let isArranged: Bool
    @Environment(\.translationService) private var t

    private var statusInfo: (text: String, color: Color) {
        if isArranged {
            (t.t("map.status.arranged"), .orange)
        } else if isActive {
            (t.t("map.status.active"), .DesignSystem.success)
        } else {
            (t.t("map.status.inactive"), .gray)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Circle().fill(statusInfo.color).frame(width: 6.0, height: 6)
            Text(statusInfo.text)
                .font(.DesignSystem.captionSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(statusInfo.color.opacity(0.9))
                .background(Capsule().fill(.ultraThinMaterial)),
        )
    }
}

// MARK: - Detail Stat Pill

private struct DetailStatPill: View {
    let icon: String
    let value: String
    let label: String?
    let color: Color
    let backgroundColor: Color
    var borderColor: Color?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)

            HStack(spacing: 2) {
                Text(value)
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                if let label {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Group {
                if let borderColor {
                    Capsule()
                        .fill(backgroundColor)
                        .overlay(
                            Capsule()
                                .stroke(borderColor, lineWidth: 1),
                        )
                } else {
                    Capsule()
                        .fill(backgroundColor)
                }
            },
        )
    }
}

// MARK: - Legacy Aliases (Backward Compatibility)

struct MapMarkerView: View {
    let item: FoodItem
    let isSelected: Bool
    let engagementStatus: PostEngagementStatus?
    let onLike: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        LiquidGlassMapMarker(
            item: item,
            isSelected: isSelected,
            engagementStatus: engagementStatus,
            onLike: onLike,
            onBookmark: onBookmark,
        )
    }
}

struct FoodMapMarker: View {
    let item: FoodItem
    let isSelected: Bool

    var body: some View {
        LiquidGlassMapMarker(
            item: item,
            isSelected: isSelected,
            engagementStatus: nil,
            onLike: {},
            onBookmark: {},
        )
    }
}

struct MapItemDetailSheet: View {
    let item: FoodItem

    var body: some View {
        LiquidGlassMapDetailSheet(item: item)
    }
}

#Preview {
    MapView(feedRepository: DependencyContainer.preview.feedRepository)
        .environment(AppState())
}

#endif
