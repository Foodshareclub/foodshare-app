//
//  SearchResultRow.swift
//  Foodshare
//
//  Search result row component for displaying food items
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Search Result Row

struct SearchResultRow: View {
    @Environment(\.translationService) private var t
    let item: FoodItem

    private var category: ListingCategory {
        ListingCategory(rawValue: item.postType) ?? .food
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Image
            if let imageUrl = item.primaryImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.DesignSystem.glassBackground)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.DesignSystem.textSecondary)
                        }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            } else {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: category.icon)
                            .font(.title2)
                            .foregroundColor(category.color)
                    }
            }

            // Details
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.postName)
                    .font(.DesignSystem.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)
                    .lineLimit(1)

                if let description = item.postDescription {
                    Text(description)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(2)
                }

                // Location (uses stripped address for privacy)
                HStack(spacing: Spacing.xs) {
                    if let address = item.displayAddress {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(address)
                            .font(.DesignSystem.captionSmall)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Category badge
                    HStack(spacing: 2) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10))
                        Text(category.localizedDisplayName(using: t))
                            .font(.DesignSystem.captionSmall)
                    }
                    .foregroundColor(category.color)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(category.color.opacity(0.15))
                    .clipShape(Capsule())
                }
                .foregroundColor(.DesignSystem.textSecondary)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }
}
