//
//  RefreshableScrollView.swift
//  Foodshare
//
//  Custom pull-to-refresh with Liquid Glass styling
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Refreshable Container

struct RefreshableContainer<Content: View>: View {
    let onRefresh: () async -> Void
    let content: Content

    @State private var isRefreshing = false

    init(
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content,
    ) {
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            isRefreshing = true
            HapticManager.light()
            await onRefresh()
            isRefreshing = false
            HapticManager.success()
        }
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.DesignSystem.textSecondary)
                .animatedAppearance(delay: 0.1)

            Text(title)
                .font(.DesignSystem.headlineMedium)
                .fontWeight(.semibold)
                .animatedAppearance(delay: 0.2)

            Text(message)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .animatedAppearance(delay: 0.3)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.DesignSystem.bodyLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.md)
                        .background(Color.DesignSystem.primary)
                        .cornerRadius(Spacing.md)
                }
                .buttonStyle(.hapticMedium)
                .animatedAppearance(delay: 0.4)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let error: String
    var retryAction: (() async -> Void)?

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.DesignSystem.headlineMedium)
                .fontWeight(.semibold)

            Text(error)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button {
                    Task {
                        isRetrying = true
                        HapticManager.light()
                        await retryAction()
                        isRetrying = false
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Try Again")
                    }
                    .font(.DesignSystem.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(Color.DesignSystem.primary)
                    .cornerRadius(Spacing.md)
                }
                .buttonStyle(.hapticMedium)
                .disabled(isRetrying)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Content State Wrapper

enum ContentState<T> {
    case loading
    case loaded(T)
    case empty
    case error(String)
}

struct ContentStateView<T, Content: View, Empty: View>: View {
    let state: ContentState<T>
    let content: (T) -> Content
    let emptyView: () -> Empty
    var retryAction: (() async -> Void)?

    init(
        state: ContentState<T>,
        @ViewBuilder content: @escaping (T) -> Content,
        @ViewBuilder emptyView: @escaping () -> Empty,
        retryAction: (() async -> Void)? = nil,
    ) {
        self.state = state
        self.content = content
        self.emptyView = emptyView
        self.retryAction = retryAction
    }

    var body: some View {
        switch state {
        case .loading:
            LoadingStateView()
                .transition(.opacity)

        case let .loaded(data):
            content(data)
                .transition(.opacity)

        case .empty:
            emptyView()
                .transition(.opacity)

        case let .error(message):
            ErrorStateView(error: message, retryAction: retryAction)
                .transition(.opacity)
        }
    }
}

// MARK: - Async Content View

struct AsyncContentView<T, Content: View>: View {
    let load: () async throws -> T
    let content: (T) -> Content

    @State private var state: ContentState<T> = .loading

    init(
        load: @escaping () async throws -> T,
        @ViewBuilder content: @escaping (T) -> Content,
    ) {
        self.load = load
        self.content = content
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                LoadingStateView()

            case let .loaded(data):
                content(data)

            case .empty:
                EmptyStateView(
                    icon: "tray",
                    title: "No Data",
                    message: "Nothing to show here",
                )

            case let .error(message):
                ErrorStateView(error: message) {
                    await loadData()
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        state = .loading
        do {
            let data = try await load()
            withAnimation(.smoothEase) {
                state = .loaded(data)
            }
        } catch {
            withAnimation(.smoothEase) {
                state = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Loading") {
        LoadingStateView("Fetching listings...")
    }

    #Preview("Empty") {
        EmptyStateView(
            icon: "tray",
            title: "No Listings",
            message: "There are no food listings in your area yet.",
            actionTitle: "Create Listing",
        ) {
            print("Create tapped")
        }
    }

    #Preview("Error") {
        ErrorStateView(error: "Network connection failed. Please check your internet connection.") {
            try? await Task.sleep(for: .seconds(1))
        }
    }
#endif
