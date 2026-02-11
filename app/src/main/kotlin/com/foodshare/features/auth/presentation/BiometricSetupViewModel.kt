package com.foodshare.features.auth.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.auth.BiometricService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class BiometricSetupViewModel @Inject constructor(
    private val biometricService: BiometricService
) : ViewModel() {

    fun enableBiometric(onComplete: () -> Unit) {
        viewModelScope.launch {
            biometricService.enableBiometric()
            onComplete()
        }
    }
}
