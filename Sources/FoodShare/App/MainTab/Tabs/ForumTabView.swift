//
//  ForumTabView.swift
//  Foodshare
//
//  Forum tab for community discussions
//


#if !SKIP
import SwiftUI

// MARK: - Forum Tab View

struct ForumTabView: View {
    @Environment(\.translationService) private var t
    @Binding var deepLinkForumPostId: Int?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ForumContainerView()
                .navigationTitle(t.t("tabs.forum"))
                .navigationDestination(for: DeepLinkRoute.self) { route in
                    switch route {
                    case let .forumPost(id):
                        DeepLinkForumPostView(postId: id)
                    default:
                        EmptyView()
                    }
                }
        }
        .onChange(of: deepLinkForumPostId) { _, newValue in
            if let postId = newValue {
                navigationPath.append(DeepLinkRoute.forumPost(postId))
                deepLinkForumPostId = nil
            }
        }
    }
}

#endif
