package com.foodshare.core.utilities

import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

object RelativeTimeFormatter {
    
    fun format(timestamp: String?): String {
        if (timestamp == null) return ""
        
        return try {
            val instant = Instant.parse(timestamp)
            val now = Instant.now()
            val duration = Duration.between(instant, now)
            
            when {
                duration.toMinutes() < 1 -> "Just now"
                duration.toMinutes() < 60 -> "${duration.toMinutes()}m"
                duration.toHours() < 24 -> "${duration.toHours()}h"
                duration.toDays() < 7 -> "${duration.toDays()}d"
                duration.toDays() < 30 -> "${duration.toDays() / 7}w"
                else -> {
                    val formatter = DateTimeFormatter.ofPattern("MMM d")
                        .withZone(ZoneId.systemDefault())
                    formatter.format(instant)
                }
            }
        } catch (e: Exception) {
            ""
        }
    }
}
