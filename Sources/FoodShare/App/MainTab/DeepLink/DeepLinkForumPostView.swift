//
//  DeepLinkForumPostView.swift
//  Foodshare
//
//  Wrapper view for deep-linking to a specific forum post
//


#if !SKIP
import SwiftUI

/// Wrapper view for deep-linking to a specific forum post
struct DeepLinkForumPostView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    let postId: Int
    @State private var post: ForumPost?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if let post {
                ForumPostDetailView(post: post, repository: appState.dependencies.forumRepository)
            } else if isLoading {
                ProgressView(t.t("status.loading_post"))
            } else if error != nil {
                ContentUnavailableView(
                    t.t("errors.not_found.post"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(t.t("errors.not_found.post_desc")),
                )
            }
        }
        .task {
            await loadPost()
        }
    }

    private func loadPost() async {
        isLoading = true
        defer { isLoading = false }

        do {
            post = try await appState.dependencies.forumRepository.fetchPost(id: postId)
        } catch {
            self.error = error
        }
    }
}

#endif
