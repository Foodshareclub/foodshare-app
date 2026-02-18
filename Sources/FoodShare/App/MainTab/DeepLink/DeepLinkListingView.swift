//
//  DeepLinkListingView.swift
//  Foodshare
//
//  Wrapper view for deep-linking to a specific listing
//


#if !SKIP
import SwiftUI

/// Wrapper view for deep-linking to a specific listing
struct DeepLinkListingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    let listingId: Int
    @State private var item: FoodItem?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if let item {
                FoodItemDetailView(item: item)
            } else if isLoading {
                ProgressView(t.t("status.loading_listing"))
            } else if error != nil {
                ContentUnavailableView(
                    t.t("errors.not_found.listing"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(t.t("errors.not_found.listing_desc")),
                )
            }
        }
        .task {
            await loadListing()
        }
    }

    private func loadListing() async {
        isLoading = true
        defer { isLoading = false }

        do {
            item = try await appState.dependencies.listingRepository.fetchListing(id: listingId)
        } catch {
            self.error = error
        }
    }
}

#endif
