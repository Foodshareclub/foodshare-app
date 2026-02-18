//
//  ShareService.swift
//  Foodshare
//
//  Native iOS share sheet service with activity tracking
//  Uses UIActivityViewController for system share sheet
//


#if !SKIP
import Foundation
import OSLog
import Supabase
#if !SKIP
import UIKit
#endif

// MARK: - Share Method

/// Method used to share content
public enum ShareMethod: String, Sendable {
    case link
    case social
    case email
    case message
    case other

    /// Map UIActivity type to ShareMethod
    static func from(activityType: UIActivity.ActivityType?) -> ShareMethod {
        guard let type = activityType else { return .other }

        switch type {
        case .copyToPasteboard:
            return .link
        case .mail:
            return .email
        case .message:
            return .message
        case .postToFacebook, .postToTwitter, .postToWeibo, .postToFlickr, .postToVimeo, .postToTencentWeibo:
            return .social
        default:
            if type.rawValue.contains("whatsapp") ||
                type.rawValue.contains("telegram") ||
                type.rawValue.contains("instagram")
            {
                return .social
            }
            return .other
        }
    }
}

// MARK: - Share Content

/// Content to be shared
struct ShareContent: Sendable {
    let title: String
    let description: String?
    let url: URL
    let image: UIImage?

    init(title: String, description: String? = nil, url: URL, image: UIImage? = nil) {
        self.title = title
        self.description = description
        self.url = url
        self.image = image
    }
}

// MARK: - Share Service

/// Service for sharing content via native iOS share sheet
@MainActor
final class ShareService {
    // MARK: - Singleton

    static let shared = ShareService(supabase: AuthenticationService.shared.supabase)

    // MARK: - Properties

    private let supabase: SupabaseClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ShareService")

    /// Base URL for sharing posts
    private let baseShareURL = "https://foodshare.club/p/"

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        logger.info("📤 [SHARE] ShareService initialized")
    }

    // MARK: - Share Methods

    /// Share a food item using native iOS share sheet
    /// - Parameters:
    ///   - item: The food item to share
    ///   - sourceView: The view to anchor the share popover (iPad)
    ///   - completion: Called with the share method used (or nil if cancelled)
    func shareFoodItem(
        _ item: FoodItem,
        from sourceView: UIView? = nil,
        completion: ((ShareMethod?) -> Void)? = nil,
    ) {
        guard let url = URL(string: "\(baseShareURL)\(item.id)") else {
            logger.error("Failed to construct share URL for item: \(item.id)")
            completion?(nil)
            return
        }

        let content = ShareContent(
            title: item.title,
            description: item.description,
            url: url,
        )

        share(content: content, postId: item.id, from: sourceView, completion: completion)
    }

    /// Share content using native iOS share sheet
    /// - Parameters:
    ///   - content: The content to share
    ///   - postId: Optional post ID for activity tracking
    ///   - sourceView: The view to anchor the share popover (iPad)
    ///   - completion: Called with the share method used (or nil if cancelled)
    func share(
        content: ShareContent,
        postId: Int? = nil,
        from sourceView: UIView? = nil,
        completion: ((ShareMethod?) -> Void)? = nil,
    ) {
        logger.info("📤 [SHARE] Sharing: \(content.title)")

        // Build share items
        var items: [Any] = []

        // Add text (title + description)
        let text = if let description = content.description {
            "\(content.title)\n\n\(description)"
        } else {
            content.title
        }
        items.append(text)

        // Add URL
        items.append(content.url)

        // Add image if available
        if let image = content.image {
            items.append(image)
        }

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil,
        )

        // Exclude some activities that don't make sense
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .saveToCameraRoll,
        ]

        // Handle completion
        activityVC.completionWithItemsHandler = { [weak self] activityType, completed, _, error in
            guard let self else { return }

            if let error {
                logger.error("❌ [SHARE] Share failed: \(error.localizedDescription)")
                completion?(nil)
                return
            }

            if completed {
                let method = ShareMethod.from(activityType: activityType)
                logger.info("✅ [SHARE] Shared via: \(method.rawValue)")

                // Track share activity
                if let postId {
                    Task {
                        await self.recordShare(postId: postId, method: method)
                    }
                }

                // Haptic feedback
                HapticManager.success()

                completion?(method)
            } else {
                logger.info("ℹ️ [SHARE] Share cancelled")
                completion?(nil)
            }
        }

        // Configure for iPad
        if let sourceView {
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        }

        // Present
        presentShareSheet(activityVC)
    }

    /// Copy link to clipboard
    func copyLink(for item: FoodItem) {
        let url = "\(baseShareURL)\(item.id)"
        UIPasteboard.general.string = url

        logger.info("📋 [SHARE] Link copied: \(url)")
        HapticManager.light()

        // Track as link share
        Task {
            await recordShare(postId: item.id, method: .link)
        }
    }

    // MARK: - Activity Tracking

    /// Record share activity in post_activity_logs
    private func recordShare(postId: Int, method: ShareMethod) async {
        struct ShareActivityLog: Encodable {
            let postId: Int
            let actorId: String
            let activityType: String
            let notes: String

            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case actorId = "actor_id"
                case activityType = "activity_type"
                case notes
            }
        }

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                logger.debug("ℹ️ [SHARE] Not tracking share - user not authenticated")
                return
            }

            try await supabase
                .from("post_activity_logs")
                .insert(ShareActivityLog(
                    postId: postId,
                    actorId: userId.uuidString,
                    activityType: "shared",
                    notes: "method:\(method.rawValue):shared_at:\(ISO8601DateFormatter().string(from: Date()))",
                ))
                .execute()

            logger.debug("📝 [SHARE] Share activity logged for post \(postId)")
        } catch {
            // Non-critical - log but don't throw
            logger.warning("⚠️ [SHARE] Failed to log share activity: \(error.localizedDescription)")
        }
    }

    // MARK: - Presentation

    /// Present share sheet from top view controller
    private func presentShareSheet(_ activityVC: UIActivityViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else
        {
            logger.error("❌ [SHARE] Cannot present share sheet - no root view controller")
            return
        }

        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(activityVC, animated: true)
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// SwiftUI view modifier for sharing
struct ShareSheetModifier: ViewModifier {
    let item: FoodItem
    @Binding var isPresented: Bool
    var onComplete: ((ShareMethod?) -> Void)?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    ShareService.shared.shareFoodItem(item) { method in
                        isPresented = false
                        onComplete?(method)
                    }
                }
            }
    }
}

extension View {
    /// Present native share sheet for a food item
    func shareSheet(
        item: FoodItem,
        isPresented: Binding<Bool>,
        onComplete: ((ShareMethod?) -> Void)? = nil,
    ) -> some View {
        modifier(ShareSheetModifier(item: item, isPresented: isPresented, onComplete: onComplete))
    }
}

#endif
