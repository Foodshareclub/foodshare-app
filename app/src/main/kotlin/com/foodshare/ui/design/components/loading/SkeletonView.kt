package com.foodshare.ui.design.components.loading

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing

/**
 * Skeleton loading state components
 *
 * Provides animated placeholders for content loading states.
 */

// MARK: - Skeleton Animation

@Composable
private fun skeletonAlpha(): Float {
    val infiniteTransition = rememberInfiniteTransition(label = "skeleton")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.6f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "skeletonAlpha"
    )
    return alpha
}

// MARK: - Basic Skeleton View

@Composable
fun SkeletonView(
    modifier: Modifier = Modifier
) {
    val alpha = skeletonAlpha()
    Box(
        modifier = modifier
            .alpha(alpha)
            .background(LiquidGlassColors.Glass.background)
    )
}

// MARK: - Skeleton Shapes

@Composable
fun SkeletonLine(
    modifier: Modifier = Modifier,
    width: Dp? = null,
    height: Dp = 16.dp
) {
    val alpha = skeletonAlpha()
    Box(
        modifier = modifier
            .then(if (width != null) Modifier.width(width) else Modifier.fillMaxWidth())
            .height(height)
            .alpha(alpha)
            .clip(RoundedCornerShape(4.dp))
            .background(LiquidGlassColors.Glass.background)
    )
}

@Composable
fun SkeletonCircle(
    modifier: Modifier = Modifier,
    size: Dp = 40.dp
) {
    val alpha = skeletonAlpha()
    Box(
        modifier = modifier
            .size(size)
            .alpha(alpha)
            .clip(CircleShape)
            .background(LiquidGlassColors.Glass.background)
    )
}

@Composable
fun SkeletonRect(
    modifier: Modifier = Modifier,
    width: Dp? = null,
    height: Dp = 100.dp,
    cornerRadius: Dp = Spacing.sm
) {
    val alpha = skeletonAlpha()
    Box(
        modifier = modifier
            .then(if (width != null) Modifier.width(width) else Modifier.fillMaxWidth())
            .height(height)
            .alpha(alpha)
            .clip(RoundedCornerShape(cornerRadius))
            .background(LiquidGlassColors.Glass.background)
    )
}

// MARK: - Skeleton Card

@Composable
fun SkeletonFoodCard(
    modifier: Modifier = Modifier
) {
    GlassCard(modifier = modifier) {
        Column {
            SkeletonRect(height = 150.dp, cornerRadius = Spacing.md)

            Column(
                modifier = Modifier.padding(Spacing.sm),
                verticalArrangement = Arrangement.spacedBy(Spacing.xs)
            ) {
                SkeletonLine(width = 180.dp, height = 20.dp)
                SkeletonLine(width = 120.dp, height = 14.dp)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    SkeletonLine(width = 60.dp, height = 12.dp)
                    SkeletonLine(width = 40.dp, height = 12.dp)
                }
            }
        }
    }
}

@Composable
fun SkeletonRoomRow(
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md)
    ) {
        SkeletonCircle(size = 50.dp)

        Column(
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
            modifier = Modifier.weight(1f)
        ) {
            SkeletonLine(width = 120.dp, height = 16.dp)
            SkeletonLine(width = 200.dp, height = 14.dp)
        }

        SkeletonLine(width = 40.dp, height = 12.dp)
    }
}

@Composable
fun SkeletonProfileHeader(
    modifier: Modifier = Modifier
) {
    GlassCard(modifier = modifier) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            SkeletonCircle(size = 80.dp)
            SkeletonLine(width = 120.dp, height = 20.dp)
            SkeletonLine(width = 80.dp, height = 14.dp)

            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.lg)
            ) {
                repeat(3) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(Spacing.xxs)
                    ) {
                        SkeletonLine(width = 30.dp, height = 20.dp)
                        SkeletonLine(width = 50.dp, height = 12.dp)
                    }
                }
            }
        }
    }
}

@Composable
fun SkeletonListingCard(
    modifier: Modifier = Modifier
) {
    GlassCard(modifier = modifier) {
        Row(
            modifier = Modifier.padding(Spacing.sm),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
        ) {
            SkeletonRect(width = 100.dp, height = 100.dp, cornerRadius = Spacing.sm)

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Spacing.xs)
            ) {
                SkeletonLine(height = 18.dp)
                SkeletonLine(width = 150.dp, height = 14.dp)
                Spacer(Modifier.height(Spacing.sm))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
                ) {
                    SkeletonLine(width = 60.dp, height = 24.dp)
                    SkeletonLine(width = 80.dp, height = 24.dp)
                }
            }
        }
    }
}

// MARK: - Skeleton List Helper

@Composable
fun SkeletonList(
    count: Int = 5,
    content: @Composable () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        repeat(count) {
            content()
        }
    }
}
