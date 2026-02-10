package com.foodshare.domain.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Category domain model
 *
 * Maps to `categories` table in Supabase
 */
@Serializable
data class Category(
    val id: Int,
    val name: String,
    @SerialName("icon_name") val iconName: String? = null,
    @SerialName("color_hex") val colorHex: String? = null,
    @SerialName("sort_order") val sortOrder: Int? = null
)

/**
 * Common listing categories for quick filtering
 */
enum class ListingCategory(
    val displayName: String,
    val iconName: String,
    val colorHex: String
) {
    PRODUCE("Produce", "leaf.fill", "#27AE60"),
    BAKERY("Bakery", "birthday.cake.fill", "#E67E22"),
    DAIRY("Dairy", "drop.fill", "#3498DB"),
    PREPARED("Prepared", "fork.knife", "#E74C3C"),
    PANTRY("Pantry", "shippingbox.fill", "#9B59B6"),
    BEVERAGES("Beverages", "cup.and.saucer.fill", "#1ABC9C"),
    OTHER("Other", "ellipsis.circle.fill", "#95A5A6");

    companion object {
        val creatableCategories: List<ListingCategory>
            get() = listOf(PRODUCE, BAKERY, DAIRY, PREPARED, PANTRY, BEVERAGES, OTHER)
    }
}
