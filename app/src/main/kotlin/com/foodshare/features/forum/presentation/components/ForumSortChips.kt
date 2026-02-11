package com.foodshare.features.forum.presentation.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.foodshare.features.forum.domain.model.ForumSortOption
import com.foodshare.ui.design.tokens.Spacing

@Composable
fun ForumSortChips(
    currentSort: ForumSortOption,
    onSortSelected: (ForumSortOption) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
    ) {
        items(ForumSortOption.entries) { sortOption ->
            FilterChip(
                selected = currentSort == sortOption,
                onClick = { onSortSelected(sortOption) },
                label = { Text(sortOption.displayName) }
            )
        }
    }
}
