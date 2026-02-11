package com.foodshare.features.insights.presentation.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.foodshare.features.insights.domain.model.MonthlyStats

@Composable
fun InsightsMonthlyChart(
    monthlyStats: List<MonthlyStats>,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(250.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(16.dp)
    ) {
        val maxValue = monthlyStats.maxOfOrNull { maxOf(it.shared, it.received) } ?: 1

        Canvas(modifier = Modifier.fillMaxSize()) {
            val barWidth = size.width / (monthlyStats.size * 2.5f)
            val spacing = barWidth * 0.3f

            monthlyStats.forEachIndexed { index, stats ->
                val x = index * (barWidth * 2 + spacing)

                // Shared bar
                val sharedHeight = (stats.shared.toFloat() / maxValue) * size.height * 0.8f
                drawRect(
                    color = Color(0xFF4CAF50),
                    topLeft = Offset(x, size.height - sharedHeight),
                    size = Size(barWidth, sharedHeight)
                )

                // Received bar
                val receivedHeight = (stats.received.toFloat() / maxValue) * size.height * 0.8f
                drawRect(
                    color = Color(0xFF2196F3),
                    topLeft = Offset(x + barWidth, size.height - receivedHeight),
                    size = Size(barWidth, receivedHeight)
                )
            }
        }

        // Legend
        Row(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            ChartLegendItem(color = Color(0xFF4CAF50), label = "Shared")
            ChartLegendItem(color = Color(0xFF2196F3), label = "Received")
        }
    }
}

@Composable
private fun ChartLegendItem(color: Color, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .background(color, RoundedCornerShape(2.dp))
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.7f)
        )
    }
}
