//
//  LoadingStateContainer.swift
//  Foodshare
//
//  A generic SwiftUI container that renders appropriate UI based on LoadingState.
//  Provides consistent loading, error, and empty state handling across the app.
//
//  Usage:
//  ```swift
//  LoadingStateContainer(state: viewModel.dataState) { items in
//      ForEach(items) { item in
//          ItemRow(item: item)
//      }
//  } onRetry: {
//      await viewModel.loadData()
//  }
//  ```
//


#if !SKIP
import SwiftUI

// MARK: - Loading State Container

/// A generic container that automatically renders the appropriate UI based on LoadingState
///
/// This component eliminates boilerplate conditional rendering and ensures consistent
/// loading, error, and empty state experiences across the app.
public struct LoadingStateContainer<T: Sendable, Content: View>: View {
    @Environment(\.translationService) private var t

    private let state: LoadingState<T>
    private let content: (T) -> Content
    private let onRetry: (() async -> Void)?
    private let emptyMessage: String
    private let emptyIcon: String

    /// Creates a LoadingStateContainer with the given state and content builder
    /// - Parameters:
    ///   - state: The current loading state
    ///   - emptyMessage: Message to display when data is empty
    ///   - emptyIcon: SF Symbol to display when data is empty
    ///   - content: Content builder that receives the loaded data
    ///   - onRetry: Optional async action to retry failed loads
    init(
        state: LoadingState<T>,
        emptyMessage: String = "No items found",
        emptyIcon: String = "tray",
        @ViewBuilder content: @escaping (T) -> Content,
        onRetry: (() async -> Void)? = nil,
    ) {
        self.state = state
        self.emptyMessage = emptyMessage
        self.emptyIcon = emptyIcon
        self.content = content
        self.onRetry = onRetry
    }

    public var body: some View {
        ZStack {
            switch state {
            case .idle:
                idleView

            case .loading:
                loadingView

            case let .loaded(value):
                loadedView(value)

            case let .refreshing(existing):
                refreshingView(existing)

            case let .loadingMore(existing):
                loadingMoreView(existing)

            case let .failed(error):
                errorView(error)

            case let .retrying(attempt, _):
                retryingView(attempt: attempt)
            }
        }
        .animation(.smooth(duration: 0.3), value: state.isLoading)
    }

    // MARK: - State Views

    @ViewBuilder
    private var idleView: some View {
        Color.clear
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.DesignSystem.primary)

            Text(t.t("common.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    @ViewBuilder
    private func loadedView(_ value: T) -> some View {
        if checkIfEmpty(value) {
            emptyStateView
        } else {
            content(value)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func refreshingView(_ existing: T) -> some View {
        ZStack {
            content(existing)
                .opacity(0.6)

            VStack {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.DesignSystem.primary)
                    .padding(Spacing.sm)
                    #if !SKIP
                    .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */, in: Capsule())
                    #else
                    .background(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                Spacer()
            }
            .padding(.top, Spacing.md)
        }
    }

    @ViewBuilder
    private func loadingMoreView(_ existing: T) -> some View {
        VStack(spacing: 0) {
            content(existing)

            HStack(spacing: Spacing.sm) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(t.t("common.loading_more"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
        }
    }

    @ViewBuilder
    private func errorView(_ error: AppError) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.DesignSystem.error)

            VStack(spacing: Spacing.sm) {
                Text(t.t("common.something_wrong"))
                    .font(.DesignSystem.titleMedium)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                Text(error.localizedDescription)
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let onRetry {
                GlassButton("Try Again", icon: "arrow.clockwise", style: .secondary) {
                    Task { await onRetry() }
                }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    @ViewBuilder
    private func retryingView(attempt: Int) -> some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.DesignSystem.primary)

            Text("Retrying... (Attempt \(attempt))")
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: emptyIcon)
                .font(.system(size: 48))
                .foregroundStyle(Color.DesignSystem.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text(t.t("common.nothing_here"))
                    .font(.DesignSystem.titleMedium)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                Text(emptyMessage)
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func checkIfEmpty(_ value: T) -> Bool {
        if let collection = value as? (any Collection) {
            return collection.isEmpty
        }
        return false
    }
}

#if !SKIP
// MARK: - Paginated Loading State Container

/// A specialized container for paginated data with infinite scroll support
public struct PaginatedLoadingStateContainer<T: Identifiable & Sendable, Content: View, Row: View>: View {
    private let state: PaginatedLoadingState<T>
    private let content: ([T]) -> Content
    private let row: (T) -> Row
    private let onLoadMore: (() async -> Void)?
    private let onRetry: (() async -> Void)?
    private let emptyMessage: String
    private let emptyIcon: String

    init(
        state: PaginatedLoadingState<T>,
        emptyMessage: String = "No items found",
        emptyIcon: String = "tray",
        @ViewBuilder content: @escaping ([T]) -> Content,
        @ViewBuilder row: @escaping (T) -> Row,
        onLoadMore: (() async -> Void)? = nil,
        onRetry: (() async -> Void)? = nil,
    ) {
        self.state = state
        self.emptyMessage = emptyMessage
        self.emptyIcon = emptyIcon
        self.content = content
        self.row = row
        self.onLoadMore = onLoadMore
        self.onRetry = onRetry
    }

    public var body: some View {
        LoadingStateContainer(
            state: state.state,
            emptyMessage: emptyMessage,
            emptyIcon: emptyIcon,
        ) { items in
            content(items)
                .overlay(alignment: .bottom) {
                    if state.hasMorePages, !state.isLoadingMore {
                        loadMoreTrigger
                    }
                }
        } onRetry: {
            await onRetry?()
        }
    }

    @ViewBuilder
    private var loadMoreTrigger: some View {
        Color.clear
            .frame(height: 1.0)
            .onAppear {
                if let onLoadMore {
                    Task { await onLoadMore() }
                }
            }
    }
}
#endif

// MARK: - Convenience Modifiers

extension View {
    /// Overlays a loading indicator when condition is true
    func loadingOverlay(_ isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.DesignSystem.scrim
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                        .padding(Spacing.lg)
                        .background(Color.DesignSystem.glassSurface.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    /// Displays an error banner when error is present
    func errorBanner(_ error: AppError?, onDismiss: @escaping () -> Void) -> some View {
        overlay(alignment: .top) {
            if let error {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.DesignSystem.error)

                    Text(error.localizedDescription)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(Spacing.md)
                .background(Color.DesignSystem.error.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: error != nil)
    }
}

// MARK: - Preview

#Preview("LoadingStateContainer") {
    struct PreviewWrapper: View {
        @Environment(\.translationService) private var t
        @State private var state: LoadingState<[String]> = .idle

        var body: some View {
            NavigationStack {
                VStack(spacing: Spacing.md) {
                    // Control buttons
                    HStack(spacing: Spacing.sm) {
                        Button("Idle") { state = .idle }
                        Button("Load") { state = .loading }
                        Button("Data") { state = .loaded(["Item 1", "Item 2", "Item 3"]) }
                        Button("Empty") { state = .loaded([]) }
                        Button("Error") { state = .failed(.networkError("Connection failed")) }
                    }
                    .font(.DesignSystem.caption)
                    .buttonStyle(.bordered)

                    // Container preview
                    LoadingStateContainer(
                        state: state,
                        emptyMessage: "Add your first item to get started",
                    ) { items in
                        List(items, id: \.self) { item in
                            Text(item)
                        }
                    } onRetry: {
                        state = .loading
                        #if SKIP
                        try? await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
                        #else
                        try? await Task.sleep(for: .seconds(1))
                        #endif
                        state = .loaded(["Reloaded Item"])
                    }
                }
                .navigationTitle(t.t("design.loading_states"))
            }
        }
    }

    return PreviewWrapper()
}

#endif
