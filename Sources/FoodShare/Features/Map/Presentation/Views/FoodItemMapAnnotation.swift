#if !SKIP
import MapKit
#endif
import SwiftUI

struct FoodItemMapAnnotation: View {
    let item: FoodItem
    let engagementStatus: PostEngagementStatus?
    let onLike: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Food item image/icon
            Circle()
                .fill(.orange.gradient)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .semibold))
                }

            // Engagement buttons
            HStack(spacing: 8) {
                Button(action: onLike) {
                    Image(systemName: engagementStatus?.isLiked == true ? "heart.fill" : "heart")
                        .foregroundColor(engagementStatus?.isLiked == true ? .red : .gray)
                        .font(.system(size: 12))
                }

                Button(action: onBookmark) {
                    Image(systemName: engagementStatus?.isBookmarked == true ? "bookmark.fill" : "bookmark")
                        .foregroundColor(engagementStatus?.isBookmarked == true ? .blue : .gray)
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
