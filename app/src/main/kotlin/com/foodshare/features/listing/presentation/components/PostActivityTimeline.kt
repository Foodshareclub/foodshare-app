package com.foodshare.features.listing.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.foodshare.domain.repository.TimelineEvent
import com.foodshare.domain.repository.TimelineEventType
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun PostActivityTimeline(
    events: List<TimelineEvent>,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(16.dp)
    ) {
        Text(
            text = "Activity Timeline",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            events.forEachIndexed { index, event ->
                TimelineEventItem(
                    event = event,
                    isLast = index == events.lastIndex
                )
            }
        }
    }
}

@Composable
private fun TimelineEventItem(
    event: TimelineEvent,
    isLast: Boolean
) {
    Row(
        modifier = Modifier.fillMaxWidth()
    ) {
        // Timeline indicator column
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.width(40.dp)
        ) {
            // Event dot
            Box(
                modifier = Modifier
                    .size(16.dp)
                    .background(getEventColor(event.type), CircleShape)
            )

            // Connecting line
            if (!isLast) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(60.dp)
                        .background(Color.White.copy(alpha = 0.3f))
                )
            }
        }

        // Event content
        Box(
            modifier = Modifier
                .weight(1f)
                .padding(start = 12.dp, bottom = if (isLast) 0.dp else 16.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color.White.copy(alpha = 0.1f))
                .padding(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    getEventIcon(event.type),
                    contentDescription = null,
                    tint = getEventColor(event.type),
                    modifier = Modifier.size(24.dp)
                )

                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = event.description,
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.White,
                            fontWeight = FontWeight.Medium
                        )

                        event.count?.let { count ->
                            Surface(
                                color = getEventColor(event.type).copy(alpha = 0.3f),
                                shape = CircleShape
                            ) {
                                Text(
                                    text = count.toString(),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }
                    }

                    Text(
                        text = formatTimestamp(event.timestamp),
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White.copy(alpha = 0.6f),
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
        }
    }
}

private fun getEventIcon(type: TimelineEventType): ImageVector {
    return when (type) {
        TimelineEventType.CREATED -> Icons.Default.Add
        TimelineEventType.VIEWED -> Icons.Default.Visibility
        TimelineEventType.MESSAGED -> Icons.Default.Message
        TimelineEventType.ARRANGED -> Icons.Default.Event
        TimelineEventType.COMPLETED -> Icons.Default.CheckCircle
    }
}

private fun getEventColor(type: TimelineEventType): Color {
    return when (type) {
        TimelineEventType.CREATED -> Color(0xFF2196F3)
        TimelineEventType.VIEWED -> Color(0xFFFFEB3B)
        TimelineEventType.MESSAGED -> Color(0xFF9C27B0)
        TimelineEventType.ARRANGED -> Color(0xFFFF9800)
        TimelineEventType.COMPLETED -> Color(0xFF4CAF50)
    }
}

private fun formatTimestamp(timestamp: String): String {
    return try {
        val instant = Instant.parse(timestamp)
        val formatter = DateTimeFormatter.ofPattern("MMM dd, yyyy 'at' HH:mm")
            .withZone(ZoneId.systemDefault())
        formatter.format(instant)
    } catch (e: Exception) {
        timestamp
    }
}
