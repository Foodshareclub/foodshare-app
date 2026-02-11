package com.foodshare.features.listing.presentation

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.jan.supabase.SupabaseClient
import com.foodshare.features.listing.presentation.components.EventType
import com.foodshare.features.listing.presentation.components.TimelineEvent
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject

@Serializable
data class TimelineEventDto(
    val id: String,
    @SerialName("listing_id") val listingId: Int,
    @SerialName("event_type") val eventType: String,
    val description: String,
    val timestamp: String,
    val count: Int? = null
)

data class TimelineUiState(
    val events: List<TimelineEvent> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class PostActivityTimelineViewModel @Inject constructor(
    private val supabaseClient: SupabaseClient,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val listingId: Int = checkNotNull(savedStateHandle.get<String>("listingId")?.toIntOrNull())

    private val _uiState = MutableStateFlow(TimelineUiState())
    val uiState: StateFlow<TimelineUiState> = _uiState.asStateFlow()

    init {
        loadTimelineEvents()
    }

    fun loadTimelineEvents() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            try {
                val events = supabaseClient.postgrest
                    .from("listing_activity_timeline")
                    .select(columns = Columns.ALL) {
                        filter {
                            eq("listing_id", listingId)
                        }
                        order("timestamp", Order.DESCENDING)
                    }
                    .decodeList<TimelineEventDto>()
                    .map { it.toDomain() }

                _uiState.update { it.copy(events = events, isLoading = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }
}

private fun TimelineEventDto.toDomain(): TimelineEvent {
    return TimelineEvent(
        id = id,
        type = when (eventType.lowercase()) {
            "created" -> EventType.CREATED
            "viewed" -> EventType.VIEWED
            "messaged" -> EventType.MESSAGED
            "arranged" -> EventType.ARRANGED
            "completed" -> EventType.COMPLETED
            else -> EventType.CREATED
        },
        description = description,
        timestamp = timestamp,
        count = count
    )
}
