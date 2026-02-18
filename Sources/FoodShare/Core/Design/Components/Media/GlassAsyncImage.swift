//
//  GlassAsyncImage.swift
//  FoodShare
//
//  Unified async image component with Liquid Glass styling.
//  Replaces scattered AsyncImage patterns with a consistent,
//  Kingfisher-based implementation featuring shimmer effects
//  and accessibility support.
//
//  Usage:
//  ```swift
//  GlassAsyncImage.avatar(url: user.avatarUrl, size: 48)
//  GlassAsyncImage.postImage(url: post.imageUrl, height: 200)
//  GlassAsyncImage(url: imageUrl, shape: .roundedRectangle(16), contentMode: .fill)
//  ```
//



#if !SKIP
import Kingfisher
import SwiftUI

// MARK: - Glass Async Image

#if !SKIP
/// A unified async image component with Liquid Glass styling
/// Uses Kingfisher for caching and loading with shimmer placeholders
struct GlassAsyncImage<Placeholder: View, Failure: View>: View {
    // MARK: - Shape Types

    enum GlassImageShape {
        case circle
        case roundedRectangle(CGFloat)
        case rectangle

        var cornerRadius: CGFloat {
            switch self {
            case .circle:
                return .infinity
            case let .roundedRectangle(radius):
                return radius
            case .rectangle:
                return 0
            }
        }
    }

    // MARK: - Properties

    let url: URL?
    let shape: GlassImageShape
    let contentMode: SwiftUI.ContentMode
    let showShimmer: Bool
    let shimmerColor: Color
    let borderWidth: CGFloat
    let borderColor: Color?
    let shadowRadius: CGFloat
    let shadowColor: Color

    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failure: () -> Failure

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    // MARK: - Initialization

    init(
        url: URL?,
        shape: GlassImageShape = GlassImageShape.roundedRectangle(CornerRadius.medium),
        contentMode: SwiftUI.ContentMode = SwiftUI.ContentMode.fill,
        showShimmer: Bool = true,
        shimmerColor: Color = Color.white,
        borderWidth: CGFloat = 0,
        borderColor: Color? = nil,
        shadowRadius: CGFloat = 0,
        shadowColor: Color = Color.black.opacity(0.1),
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.shape = shape
        self.contentMode = contentMode
        self.showShimmer = showShimmer
        self.shimmerColor = shimmerColor
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.shadowRadius = shadowRadius
        self.shadowColor = shadowColor
        self.placeholder = placeholder
        self.failure = failure
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .placeholder { placeholderView }
                    .onFailure { _ in }
                    .fade(duration: reduceMotion ? 0 : 0.25)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == SwiftUI.ContentMode.fill ? SwiftUI.ContentMode.fill : SwiftUI.ContentMode.fit)
            } else {
                failure()
            }
        }
        .clipShape(clipShape)
        .overlay(borderOverlay)
        .shadow(color: shadowColor, radius: shadowRadius)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var placeholderView: some View {
        if showShimmer && !reduceMotion {
            placeholder()
                .glassShimmer(isActive: true, color: shimmerColor)
        } else {
            placeholder()
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if borderWidth > 0, let borderColor {
            switch shape {
            case .circle:
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
            case let .roundedRectangle(radius):
                RoundedRectangle(cornerRadius: radius)
                    .stroke(borderColor, lineWidth: borderWidth)
            case .rectangle:
                Rectangle()
                    .stroke(borderColor, lineWidth: borderWidth)
            }
        }
    }

    private var clipShape: AnyShape {
        switch shape {
        case .circle:
            return AnyShape(Circle())
        case let .roundedRectangle(radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius))
        case .rectangle:
            return AnyShape(Rectangle())
        }
    }
}

// MARK: - Convenience Initializers with Default Placeholders

extension GlassAsyncImage where Placeholder == GlassShimmerPlaceholder, Failure == GlassImageFallback {
    /// Creates a GlassAsyncImage with default glass placeholders
    init(
        url: URL?,
        shape: GlassImageShape = GlassImageShape.roundedRectangle(CornerRadius.medium),
        contentMode: SwiftUI.ContentMode = SwiftUI.ContentMode.fill,
        showShimmer: Bool = true,
        fallbackIcon: String = "photo",
        fallbackColor: Color = Color.DesignSystem.textSecondary
    ) {
        self.init(
            url: url,
            shape: shape,
            contentMode: contentMode,
            showShimmer: showShimmer,
            shimmerColor: Color.white,
            borderWidth: 0,
            borderColor: nil,
            shadowRadius: 0,
            shadowColor: Color.clear,
            placeholder: { GlassShimmerPlaceholder() },
            failure: { GlassImageFallback(icon: fallbackIcon, iconColor: fallbackColor) }
        )
    }
}

// MARK: - Factory Methods

extension GlassAsyncImage where Placeholder == GlassShimmerPlaceholder, Failure == GlassAvatarFallback {
    /// Creates an avatar-styled image with circle shape
    /// - Parameters:
    ///   - url: The image URL (can be String or URL)
    ///   - size: The avatar size (width and height)
    ///   - borderWidth: Border width (default 2)
    ///   - borderColor: Border gradient colors
    /// - Returns: Configured GlassAsyncImage for avatars
    static func avatar(
        url: URL?,
        size: CGFloat,
        borderWidth: CGFloat = 2,
        borderGradient: [Color] = [Color.DesignSystem.themed.gradientStart, Color.DesignSystem.themed.gradientEnd]
    ) -> some View {
        GlassAsyncImage<GlassShimmerPlaceholder, GlassAvatarFallback>(
            url: url,
            shape: GlassImageShape.circle,
            contentMode: SwiftUI.ContentMode.fill,
            showShimmer: true,
            shimmerColor: Color.white,
            borderWidth: 0,
            borderColor: nil,
            shadowRadius: 4,
            shadowColor: Color.DesignSystem.themed.glow.opacity(0.2),
            placeholder: { GlassShimmerPlaceholder() },
            failure: { GlassAvatarFallback() }
        )
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: borderGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: borderWidth
                )
        )
    }

    /// Creates an avatar from a string URL
    static func avatar(
        urlString: String?,
        size: CGFloat,
        borderWidth: CGFloat = 2,
        borderGradient: [Color] = [Color.DesignSystem.themed.gradientStart, Color.DesignSystem.themed.gradientEnd]
    ) -> some View {
        avatar(
            url: urlString.flatMap { URL(string: $0) },
            size: size,
            borderWidth: borderWidth,
            borderGradient: borderGradient
        )
    }
}

extension GlassAsyncImage where Placeholder == GlassShimmerPlaceholder, Failure == GlassImageFallback {
    /// Creates a post image with rounded corners
    /// - Parameters:
    ///   - url: The image URL
    ///   - height: The image height
    ///   - cornerRadius: Corner radius (default medium)
    /// - Returns: Configured GlassAsyncImage for post images
    static func postImage(
        url: URL?,
        height: CGFloat,
        cornerRadius: CGFloat = CornerRadius.medium
    ) -> some View {
        GlassAsyncImage<GlassShimmerPlaceholder, GlassImageFallback>(
            url: url,
            shape: GlassImageShape.roundedRectangle(cornerRadius),
            contentMode: SwiftUI.ContentMode.fill,
            showShimmer: true,
            shimmerColor: Color.white,
            borderWidth: 1,
            borderColor: Color.DesignSystem.glassBorder,
            shadowRadius: 8,
            shadowColor: Color.black.opacity(0.08),
            placeholder: { GlassShimmerPlaceholder() },
            failure: { GlassImageFallback(icon: "photo", iconColor: Color.DesignSystem.textSecondary) }
        )
        .frame(height: height)
    }

    /// Creates a card thumbnail image
    /// - Parameters:
    ///   - url: The image URL
    ///   - size: The thumbnail size (square)
    /// - Returns: Configured GlassAsyncImage for thumbnails
    static func thumbnail(
        url: URL?,
        size: CGFloat,
        cornerRadius: CGFloat = CornerRadius.small
    ) -> some View {
        GlassAsyncImage<GlassShimmerPlaceholder, GlassImageFallback>(
            url: url,
            shape: GlassImageShape.roundedRectangle(cornerRadius),
            contentMode: SwiftUI.ContentMode.fill,
            showShimmer: true,
            shimmerColor: Color.white,
            borderWidth: 0,
            borderColor: nil,
            shadowRadius: 4,
            shadowColor: Color.black.opacity(0.1),
            placeholder: { GlassShimmerPlaceholder() },
            failure: { GlassImageFallback(icon: "photo", iconColor: Color.DesignSystem.textSecondary) }
        )
        .frame(width: size, height: size)
    }

    /// Creates a hero/banner image (full width)
    /// - Parameters:
    ///   - url: The image URL
    ///   - height: The banner height
    /// - Returns: Configured GlassAsyncImage for banners
    static func banner(
        url: URL?,
        height: CGFloat
    ) -> some View {
        GlassAsyncImage<GlassShimmerPlaceholder, GlassImageFallback>(
            url: url,
            shape: GlassImageShape.roundedRectangle(0),
            contentMode: SwiftUI.ContentMode.fill,
            showShimmer: true,
            shimmerColor: Color.white,
            borderWidth: 0,
            borderColor: nil,
            shadowRadius: 0,
            shadowColor: Color.clear,
            placeholder: { GlassShimmerPlaceholder() },
            failure: { GlassImageFallback(icon: "photo", iconColor: Color.DesignSystem.textSecondary) }
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}
#endif

// MARK: - Placeholder Components

/// Shimmer placeholder for loading state
struct GlassShimmerPlaceholder: View {
    var body: some View {
        Color.DesignSystem.glassBackground
    }
}

/// Fallback view for failed image loads
struct GlassImageFallback: View {
    let icon: String
    let iconColor: Color

    init(icon: String = "photo", iconColor: Color = .DesignSystem.textSecondary) {
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        ZStack {
            Color.DesignSystem.glassBackground
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)
        }
    }
}

/// Avatar-specific fallback with person icon and gradient
struct GlassAvatarFallback: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.DesignSystem.themed.gradientStart.opacity(0.3),
                    Color.DesignSystem.themed.gradientEnd.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
    }
}

// MARK: - Preview

#if DEBUG && !SKIP
#Preview("GlassAsyncImage Examples") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Text("Avatar Examples")
                .font(.DesignSystem.headlineMedium)

            HStack(spacing: Spacing.lg) {
                GlassAsyncImage.avatar(
                    url: URL(string: "https://picsum.photos/200"),
                    size: 60
                )

                GlassAsyncImage.avatar(
                    url: nil,
                    size: 60
                )

                GlassAsyncImage.avatar(
                    urlString: "https://picsum.photos/201",
                    size: 60,
                    borderGradient: [.orange, .pink]
                )
            }

            Divider()

            Text("Post Image Examples")
                .font(.DesignSystem.headlineMedium)

            GlassAsyncImage.postImage(
                url: URL(string: "https://picsum.photos/400/200"),
                height: 180
            )

            GlassAsyncImage.postImage(
                url: nil,
                height: 120
            )

            Divider()

            Text("Thumbnail Examples")
                .font(.DesignSystem.headlineMedium)

            HStack(spacing: Spacing.md) {
                GlassAsyncImage.thumbnail(
                    url: URL(string: "https://picsum.photos/100"),
                    size: 80
                )

                GlassAsyncImage.thumbnail(
                    url: URL(string: "https://picsum.photos/101"),
                    size: 80
                )

                GlassAsyncImage.thumbnail(
                    url: nil,
                    size: 80
                )
            }

            Divider()

            Text("Banner Example")
                .font(.DesignSystem.headlineMedium)

            GlassAsyncImage.banner(
                url: URL(string: "https://picsum.photos/800/200"),
                height: 150
            )
        }
        .padding()
    }
    .background(Color.backgroundGradient)
}

#endif

#endif
