package com.foodshare.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Data Transfer Object for categories.
 *
 * Used for Supabase-kt serialization (maps to `categories` table).
 * Converts to/from Swift Category via generated bindings.
 */
@Serializable
data class CategoryDto(
    val id: Int,
    val name: String,
    @SerialName("icon_name") val iconName: String? = null,
    @SerialName("color_hex") val colorHex: String? = null,
    @SerialName("sort_order") val sortOrder: Int? = null
) {
    /**
     * Convert DTO to domain model.
     */
    fun toDomain(): com.foodshare.domain.model.Category {
        return com.foodshare.domain.model.Category(
            id = id,
            name = name,
            iconName = iconName,
            colorHex = colorHex,
            sortOrder = sortOrder
        )
    }

    companion object {
        /**
         * Create DTO from domain model.
         */
        fun fromDomain(category: com.foodshare.domain.model.Category): CategoryDto {
            return CategoryDto(
                id = category.id,
                name = category.name,
                iconName = category.iconName,
                colorHex = category.colorHex,
                sortOrder = category.sortOrder
            )
        }
    }
}
