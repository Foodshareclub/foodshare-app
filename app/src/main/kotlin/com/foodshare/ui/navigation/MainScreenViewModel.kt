package com.foodshare.ui.navigation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.domain.repository.ChatRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MainScreenViewModel @Inject constructor(
    private val chatRepository: ChatRepository
) : ViewModel() {

    private val _unreadCount = MutableStateFlow(0)
    val unreadCount: StateFlow<Int> = _unreadCount.asStateFlow()

    init {
        loadUnreadCount()
    }

    private fun loadUnreadCount() {
        viewModelScope.launch {
            chatRepository.getUnreadCount()
                .onSuccess { count -> _unreadCount.value = count }
                .onFailure { _unreadCount.value = 0 }
        }
    }

    fun refreshUnreadCount() = loadUnreadCount()
}
