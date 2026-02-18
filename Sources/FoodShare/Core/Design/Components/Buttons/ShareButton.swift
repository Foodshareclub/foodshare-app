//
//  ShareButton.swift
//  Foodshare
//
//  Native iOS share button with glass styling
//  Triggers system share sheet via ShareService
//


#if !SKIP
import SwiftUI

// MARK: - Share Button

/// Glass-styled share button that triggers native iOS share sheet
struct ShareButton: View {
    // MARK: - Properties
    
    let item: FoodItem
    let style: Style
    let showLabel: Bool
    var onShare: ((ShareMethod?) -> Void)?
    
    // MARK: - State

    @State private var isSharing = false
    @Environment(\.translationService) private var t
    
    // MARK: - Style
    
    enum Style {
        case icon       // Icon only
        case pill       // Icon + label in pill shape
        case glass      // Full glass button style
        
        var iconSize: CGFloat {
            switch self {
            case .icon: 22
            case .pill: 18
            case .glass: 20
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        item: FoodItem,
        style: Style = .icon,
        showLabel: Bool = false,
        onShare: ((ShareMethod?) -> Void)? = nil
    ) {
        self.item = item
        self.style = style
        self.showLabel = showLabel || style == .pill || style == .glass
        self.onShare = onShare
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: share) {
            content
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.94, haptic: .light))
        .accessibilityLabel(t.t("accessibility.share_item", args: ["title": item.title]))
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch style {
        case .icon:
            iconOnlyContent
        case .pill:
            pillContent
        case .glass:
            glassContent
        }
    }
    
    private var iconOnlyContent: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: style.iconSize, weight: .medium))
            .foregroundColor(.DesignSystem.textSecondary)
            .frame(width: 44.0, height: 44)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
    
    private var pillContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: style.iconSize, weight: .medium))
            
            if showLabel {
                Text("Share")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .foregroundColor(.DesignSystem.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var glassContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: style.iconSize, weight: .semibold))
            
            if showLabel {
                Text("Share")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandTeal.opacity(0.9),
                                Color.DesignSystem.brandCyan.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.DesignSystem.brandTeal.opacity(0.4), radius: 12, y: 6)
        )
    }
    
    // MARK: - Actions
    
    private func share() {
        ShareService.shared.shareFoodItem(item) { method in
            onShare?(method)
        }
    }
}

// MARK: - Copy Link Button

/// Button to copy post link to clipboard
struct CopyLinkButton: View {
    let item: FoodItem
    var onCopy: (() -> Void)?

    @State private var copied = false
    @Environment(\.translationService) private var t

    var body: some View {
        Button(action: copyLink) {
            HStack(spacing: 6) {
                Image(systemName: copied ? "checkmark" : "link")
                    .font(.system(size: 16, weight: .medium))
                
                Text(copied ? t.t("common.copied") : t.t("common.copy_link"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(copied ? .DesignSystem.success : .DesignSystem.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(copied ? Color.DesignSystem.success.opacity(0.12) : Color.white.opacity(0.06))
                    .overlay(
                        Capsule()
                            .stroke(
                                copied ? Color.DesignSystem.success.opacity(0.3) : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: copied)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.94, haptic: .none))
        .accessibilityLabel(t.t("accessibility.copy_link"))
    }
    
    private func copyLink() {
        ShareService.shared.copyLink(for: item)
        
        copied = true
        onCopy?()

        // Reset after delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copied = false
        }
    }
}

// MARK: - Engagement Bar

/// Combined engagement bar with like, share, and optional bookmark
struct EngagementBar: View {
    let item: FoodItem
    let initialLikeCount: Int
    let initialIsLiked: Bool
    let showShareButton: Bool
    let showCopyLink: Bool
    
    init(
        item: FoodItem,
        initialLikeCount: Int = 0,
        initialIsLiked: Bool = false,
        showShareButton: Bool = true,
        showCopyLink: Bool = false
    ) {
        self.item = item
        self.initialLikeCount = initialLikeCount
        self.initialIsLiked = initialIsLiked
        self.showShareButton = showShareButton
        self.showCopyLink = showCopyLink
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Like button
            #if !SKIP
            LikeButton(
                postId: item.id,
                initialLikeCount: initialLikeCount,
                initialIsLiked: initialIsLiked,
                size: .medium
            )
            #endif
            
            Spacer()
            
            // Copy link button
            if showCopyLink {
                CopyLinkButton(item: item)
            }
            
            // Share button
            if showShareButton {
                ShareButton(item: item, style: .icon)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Preview

#if DEBUG
private let previewItem = FoodItem.fixture()

#Preview("Share Buttons") {
    VStack(spacing: 24) {
        Text("Share Button Styles")
            .font(.headline)
            .foregroundColor(.white)

        HStack(spacing: 20) {
            ShareButton(item: previewItem, style: .icon)
            ShareButton(item: previewItem, style: .pill)
            ShareButton(item: previewItem, style: .glass)
        }

        Divider()
            .background(Color.white.opacity(0.2))

        Text("Copy Link Button")
            .font(.headline)
            .foregroundColor(.white)

        CopyLinkButton(item: previewItem)

        Divider()
            .background(Color.white.opacity(0.2))

        Text("Engagement Bar")
            .font(.headline)
            .foregroundColor(.white)

        EngagementBar(
            item: previewItem,
            initialLikeCount: 42,
            initialIsLiked: false,
            showShareButton: true,
            showCopyLink: true
        )
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    .padding()
    .background(Color.black)
}
#endif

#endif
