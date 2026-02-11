package com.foodshare.features.challenges.presentation.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.foodshare.features.challenges.presentation.LeaderboardViewModel
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

@Composable
fun TimePeriodFilterRow(
    selectedPeriod: LeaderboardViewModel.TimePeriod,
    onPeriodSelected: (LeaderboardViewModel.TimePeriod) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        items(LeaderboardViewModel.TimePeriod.entries) { period ->
            FilterChip(
                selected = selectedPeriod == period,
                onClick = { onPeriodSelected(period) },
                label = {
                    Text(
                        text = period.displayName,
                        color = if (selectedPeriod == period) Color.White
                        else Color.White.copy(alpha = 0.7f)
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = LiquidGlassColors.brandPink.copy(alpha = 0.8f),
                    containerColor = Color.White.copy(alpha = 0.1f),
                    selectedLabelColor = Color.White,
                    labelColor = Color.White.copy(alpha = 0.7f)
                ),
                border = FilterChipDefaults.filterChipBorder(
                    borderColor = Color.White.copy(alpha = 0.2f),
                    selectedBorderColor = LiquidGlassColors.brandPink,
                    enabled = true,
                    selected = selectedPeriod == period
                )
            )
        }
    }
}

@Composable
fun CategoryFilterRow(
    selectedCategory: LeaderboardViewModel.LeaderboardCategory,
    onCategorySelected: (LeaderboardViewModel.LeaderboardCategory) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        items(LeaderboardViewModel.LeaderboardCategory.entries) { category ->
            FilterChip(
                selected = selectedCategory == category,
                onClick = { onCategorySelected(category) },
                label = {
                    Text(
                        text = category.displayName,
                        color = if (selectedCategory == category) Color.White
                        else Color.White.copy(alpha = 0.7f)
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = LiquidGlassColors.brandTeal.copy(alpha = 0.8f),
                    containerColor = Color.White.copy(alpha = 0.1f),
                    selectedLabelColor = Color.White,
                    labelColor = Color.White.copy(alpha = 0.7f)
                ),
                border = FilterChipDefaults.filterChipBorder(
                    borderColor = Color.White.copy(alpha = 0.2f),
                    selectedBorderColor = LiquidGlassColors.brandTeal,
                    enabled = true,
                    selected = selectedCategory == category
                )
            )
        }
    }
}
