//
//  HeroTransitions.swift
//  FoodShare
//
//  Hero transition system for fluid morphing animations between views.
//  Uses matchedGeometryEffect for seamless element transformations.
//
//  Features:
//  - Card → Detail hero transitions
//  - Avatar → Profile morphing
//  - Image gallery transitions
//  - Cross-fade with geometry matching
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Hero Animation Namespace

/// Environment key for hero animation namespace
private struct HeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var heroNamespace: Namespace.ID? {
        get { self[HeroNamespaceKey.self] }
        set { self[HeroNamespaceKey.self] = newValue }
    }
}

// MARK: - Hero ID Protocol

/// Protocol for generating unique hero IDs
protocol HeroIdentifiable {
    var heroID: String { get }
}

/// Standard hero element types for consistent naming
enum HeroElement: String {
    case container
    case image
    case title
    case subtitle
    case avatar
    case badge
    case background
    case icon
    case card
}

// MARK: - Hero Transition Container

/// Container that provides hero animation namespace to children
struct HeroTransitionContainer<Content: View>: View {
    @Namespace private var heroNamespace
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.heroNamespace, heroNamespace)
    }
}

// MARK: - Hero View Modifier

/// View modifier for hero transitions with matchedGeometryEffect
struct HeroModifier: ViewModifier {
    let id: String
    let element: HeroElement
    let namespace: Namespace.ID
    let isSource: Bool
    let properties: MatchedGeometryProperties
    let anchor: UnitPoint

    init(
        id: String,
        element: HeroElement,
        namespace: Namespace.ID,
        isSource: Bool = true,
        properties: MatchedGeometryProperties = .frame,
        anchor: UnitPoint = .center,
    ) {
        self.id = id
        self.element = element
        self.namespace = namespace
        self.isSource = isSource
        self.properties = properties
        self.anchor = anchor
    }

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: "\(id)_\(element.rawValue)",
                in: namespace,
                properties: properties,
                anchor: anchor,
                isSource: isSource,
            )
    }
}

// MARK: - Hero View Extensions

extension View {
    /// Apply hero transition to a view element
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the hero group
    ///   - element: The type of element being transitioned
    ///   - namespace: The animation namespace
    ///   - isSource: Whether this is the source or destination view
    ///   - properties: Which properties to match (.frame, .position, .size)
    ///   - anchor: The anchor point for the transition
    func hero(
        id: String,
        element: HeroElement,
        in namespace: Namespace.ID,
        isSource: Bool = true,
        properties: MatchedGeometryProperties = .frame,
        anchor: UnitPoint = .center,
    ) -> some View {
        modifier(HeroModifier(
            id: id,
            element: element,
            namespace: namespace,
            isSource: isSource,
            properties: properties,
            anchor: anchor,
        ))
    }

    /// Apply hero transition using environment namespace
    func hero(
        id: String,
        element: HeroElement,
        isSource: Bool = true,
        properties: MatchedGeometryProperties = .frame,
    ) -> some View {
        modifier(EnvironmentHeroModifier(
            id: id,
            element: element,
            isSource: isSource,
            properties: properties,
        ))
    }
}

/// Hero modifier that reads namespace from environment
private struct EnvironmentHeroModifier: ViewModifier {
    let id: String
    let element: HeroElement
    let isSource: Bool
    let properties: MatchedGeometryProperties

    @Environment(\.heroNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content
                .matchedGeometryEffect(
                    id: "\(id)_\(element.rawValue)",
                    in: namespace,
                    properties: properties,
                    isSource: isSource,
                )
        } else {
            content
        }
    }
}

// MARK: - Hero Card Transition

/// A card that supports hero transitions to a detail view
struct HeroCard<Content: View, DetailContent: View>: View {
    let id: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let detailContent: () -> DetailContent

    @Namespace private var namespace
    @State private var showingDetail = false

    var body: some View {
        ZStack {
            if !isExpanded {
                // Card view
                content()
                    .hero(id: id, element: .card, in: namespace, isSource: true)
                    .onTapGesture {
                        withAnimation(ProMotionAnimation.smooth) {
                            isExpanded = true
                        }
                    }
            } else {
                // Detail view
                detailContent()
                    .hero(id: id, element: .card, in: namespace, isSource: false)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(ProMotionAnimation.fluid),
                        removal: .opacity.animation(ProMotionAnimation.quick),
                    ))
            }
        }
    }
}

// MARK: - Hero Image Transition

/// An image that morphs between thumbnail and full-screen
struct HeroImage: View {
    let id: String
    let url: URL?
    let placeholder: Image
    let namespace: Namespace.ID
    let isExpanded: Bool
    let cornerRadius: CGFloat

    init(
        id: String,
        url: URL?,
        placeholder: Image = Image(systemName: "photo"),
        namespace: Namespace.ID,
        isExpanded: Bool,
        cornerRadius: CGFloat = 12,
    ) {
        self.id = id
        self.url = url
        self.placeholder = placeholder
        self.namespace = namespace
        self.isExpanded = isExpanded
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: isExpanded ? .fit : .fill)
            case .failure:
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            case .empty:
                ProgressView()
            @unknown default:
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : cornerRadius))
        .hero(id: id, element: .image, in: namespace, isSource: !isExpanded)
    }
}

// MARK: - Hero Avatar Transition

/// An avatar that morphs to a larger profile image
struct HeroAvatar: View {
    let id: String
    let url: URL?
    let size: CGFloat
    let namespace: Namespace.ID
    let isExpanded: Bool

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure, .empty:
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            @unknown default:
                Image(systemName: "person.circle.fill")
                    .resizable()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.primary.opacity(0.6),
                            Color.DesignSystem.secondary.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: isExpanded ? 3 : 2,
                ),
        )
        .hero(id: id, element: .avatar, in: namespace, isSource: !isExpanded)
    }
}

// MARK: - Morphing Text Transition

/// Text that morphs between styles during hero transitions
struct HeroText: View {
    let id: String
    let text: String
    let font: Font
    let namespace: Namespace.ID
    let isExpanded: Bool

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Color.DesignSystem.text)
            .hero(id: id, element: .title, in: namespace, isSource: !isExpanded)
    }
}

// MARK: - Hero Transition Manager

/// Manages hero transition state across multiple views
@MainActor
@Observable
final class HeroTransitionManager {
    static let shared = HeroTransitionManager()

    /// Currently expanded hero ID
    private(set) var expandedHeroID: String?

    /// Animation in progress
    private(set) var isAnimating = false

    private init() {}

    /// Expand a hero element
    func expand(id: String) {
        guard !isAnimating else { return }
        isAnimating = true

        withAnimation(ProMotionAnimation.smooth) {
            expandedHeroID = id
        }

        // Reset animation flag after animation completes
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            isAnimating = false
        }
    }

    /// Collapse the current hero element
    func collapse() {
        guard !isAnimating else { return }
        isAnimating = true

        withAnimation(ProMotionAnimation.smooth) {
            expandedHeroID = nil
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            isAnimating = false
        }
    }

    /// Check if a specific hero is expanded
    func isExpanded(_ id: String) -> Bool {
        expandedHeroID == id
    }
}

// MARK: - Hero Transition Presets

/// Pre-configured hero transition animations
enum HeroTransitionPreset {
    /// Card to detail - expands from card to full screen
    case cardToDetail

    /// Avatar to profile - circular expansion
    case avatarToProfile

    /// Thumbnail to gallery - image zoom
    case thumbnailToGallery

    /// List item to detail - slide and expand
    case listToDetail

    var animation: Animation {
        switch self {
        case .cardToDetail:
            ProMotionAnimation.smooth
        case .avatarToProfile:
            ProMotionAnimation.fluid
        case .thumbnailToGallery:
            .interpolatingSpring(stiffness: 180, damping: 22)
        case .listToDetail:
            ProMotionAnimation.quick
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Hero Transitions") {
        struct HeroPreview: View {
            @State private var selectedCard: String?
            @Namespace private var namespace

            var body: some View {
                ZStack {
                    Color.DesignSystem.background.ignoresSafeArea()

                    if selectedCard == nil {
                        // Card grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                            ForEach(0 ..< 4) { index in
                                let id = "card_\(index)"
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.DesignSystem.primary.opacity(0.3))
                                        .frame(height: 100)
                                        .hero(id: id, element: .image, in: namespace)

                                    Text("Card \(index + 1)")
                                        .font(Font.DesignSystem.headlineSmall)
                                        .hero(id: id, element: .title, in: namespace)
                                }
                                .padding(Spacing.sm)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .hero(id: id, element: .container, in: namespace)
                                .onTapGesture {
                                    withAnimation(ProMotionAnimation.smooth) {
                                        selectedCard = id
                                    }
                                }
                            }
                        }
                        .padding(Spacing.md)
                    } else if let id = selectedCard {
                        // Detail view
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color.DesignSystem.primary.opacity(0.3))
                                .frame(height: 300)
                                .hero(id: id, element: .image, in: namespace)

                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("Detail View")
                                    .font(Font.DesignSystem.displaySmall)
                                    .hero(id: id, element: .title, in: namespace)

                                Text("This is the expanded detail content that appears when you tap a card.")
                                    .font(Font.DesignSystem.bodyLarge)
                                    .foregroundStyle(Color.DesignSystem.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.lg)

                            Spacer()
                        }
                        .hero(id: id, element: .container, in: namespace)
                        .background(Color.DesignSystem.background)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(ProMotionAnimation.smooth) {
                                selectedCard = nil
                            }
                        }
                    }
                }
            }
        }

        return HeroPreview()
    }
#endif
