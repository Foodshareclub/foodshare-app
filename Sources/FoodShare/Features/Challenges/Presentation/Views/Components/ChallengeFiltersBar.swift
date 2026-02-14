//
//  ChallengeFiltersBar.swift
//  Foodshare
//
//  Extracted challenge filter chips component
//

import FoodShareDesignSystem
import SwiftUI

struct ChallengeFiltersBar: View {
    @Bindable var viewModel: ChallengesViewModel
    var onFilterChanged: (() -> Void)?
    @Environment(\.translationService) private var t

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(ChallengesViewModel.ChallengeFilter.allCases, id: \.self) { filter in
                    FilterChipView(
                        title: filter.localizedDisplayName(using: t),
                        count: countForFilter(filter),
                        isSelected: viewModel.selectedFilter == filter,
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedFilter = filter
                        }
                        HapticManager.light()
                        onFilterChanged?()
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Spacing.sm)
    }

    private func countForFilter(_ filter: ChallengesViewModel.ChallengeFilter) -> Int {
        switch filter {
        case .all:
            viewModel.publishedChallenges.count
        case .joined:
            viewModel.joinedChallengesCount
        case .completed:
            viewModel.completedChallengesCount
        }
    }
}

// MARK: - Filter Chip View

struct FilterChipView: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.DesignSystem.labelSmall)
                    .fontWeight(isSelected ? .bold : .medium)

                if let count {
                    Text("\(count)")
                        .font(.DesignSystem.captionSmall)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .DesignSystem.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                        ? Color.white.opacity(0.25)
                                        : Color.DesignSystem.glassBackground,
                                ),
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .DesignSystem.text)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing,
                                ),
                            )
                            .shadow(color: .DesignSystem.brandGreen.opacity(0.4), radius: 8, y: 2)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                            )
                    }
                },
            )
        }
        .buttonStyle(.plain)
    }
}
