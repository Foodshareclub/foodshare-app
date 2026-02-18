//
//  BookmarkButton.swift
//  Foodshare
//
//  Animated bookmark button with optimistic updates
//  ProMotion 120Hz optimized with interpolating springs
//


#if !SKIP
import SwiftUI

// MARK: - Bookmark Button

/// Animated bookmark button for saving posts
/// Features optimistic updates and smooth 120Hz animations
struct BookmarkButton: View {
    // MARK: - Properties
    
    let postId: Int
    let initialIsBookmarked: Bool
    let size: Size
    var onToggle: ((Bool) -> Void)?
    
    // MARK: - State
    
    @State private var isBookmarked: Bool
    @State private var isAnimating = false
    @State private var isLoading = false
    
    // MARK: - Size
    
    enum Size {
        case small   // 18pt icon
        case medium  // 22pt icon
        case large   // 28pt icon
        
        var iconSize: CGFloat {
            switch self {
            case .small: 18
            case .medium: 22
            case .large: 28
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: 8
            case .medium: 10
            case .large: 12
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        postId: Int,
        initialIsBookmarked: Bool = false,
        size: Size = .medium,
        onToggle: ((Bool) -> Void)? = nil
    ) {
        self.postId = postId
        self.initialIsBookmarked = initialIsBookmarked
        self.size = size
        self.onToggle = onToggle
        
        _isBookmarked = State(initialValue: initialIsBookmarked)
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: toggleBookmark) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundStyle(bookmarkGradient)
                .scaleEffect(isAnimating ? 1.25 : 1.0)
                .rotationEffect(.degrees(isAnimating ? 10 : 0))
                // ProMotion 120Hz optimized spring
                .animation(
                    .interpolatingSpring(stiffness: 300, damping: 12),
                    value: isAnimating
                )
                .animation(
                    .interpolatingSpring(stiffness: 400, damping: 20),
                    value: isBookmarked
                )
                .padding(size.padding)
                .background(backgroundView)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.9, haptic: .none))
        .disabled(isLoading)
        .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark post")
    }
    
    // MARK: - Subviews
    
    private var bookmarkGradient: some ShapeStyle {
        if isBookmarked {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.DesignSystem.brandTeal, .DesignSystem.brandCyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color.DesignSystem.textSecondary)
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if isBookmarked {
            Circle()
                .fill(Color.DesignSystem.brandTeal.opacity(0.12))
                .overlay(
                    Circle()
                        .stroke(Color.DesignSystem.brandTeal.opacity(0.2), lineWidth: 1)
                )
        } else {
            Circle()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Actions
    
    private func toggleBookmark() {
        guard !isLoading else { return }
        
        // Optimistic update
        let wasBookmarked = isBookmarked
        isBookmarked.toggle()
        
        // Trigger animation
        isAnimating = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            isAnimating = false
        }
        
        // Haptic feedback
        HapticManager.light()
        
        // Perform actual toggle
        isLoading = true
        
        Task {
            do {
                let result = try await PostEngagementService.shared.toggleBookmark(postId: postId)
                
                await MainActor.run {
                    isBookmarked = result
                    isLoading = false
                    onToggle?(result)
                }
            } catch {
                await MainActor.run {
                    // Revert on error
                    isBookmarked = wasBookmarked
                    isLoading = false
                    HapticManager.error()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Bookmark Buttons") {
    VStack(spacing: 24) {
        Text("Bookmark Button Sizes")
            .font(.headline)
            .foregroundColor(.white)
        
        HStack(spacing: 20) {
            BookmarkButton(postId: 1, initialIsBookmarked: false, size: .small)
            BookmarkButton(postId: 2, initialIsBookmarked: true, size: .medium)
            BookmarkButton(postId: 3, initialIsBookmarked: false, size: .large)
        }
        
        Divider()
            .background(Color.white.opacity(0.2))
        
        Text("States")
            .font(.headline)
            .foregroundColor(.white)
        
        HStack(spacing: 20) {
            VStack {
                BookmarkButton(postId: 4, initialIsBookmarked: false)
                Text("Not Saved")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            VStack {
                BookmarkButton(postId: 5, initialIsBookmarked: true)
                Text("Saved")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    .padding()
    .background(Color.black)
}

#endif
