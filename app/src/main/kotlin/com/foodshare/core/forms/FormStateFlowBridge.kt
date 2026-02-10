package com.foodshare.core.forms

import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map

/**
 * Flow-based reactive wrappers for FormStateBridge.
 *
 * Architecture (Frameo pattern):
 * - Wraps FormStateBridge with Kotlin Flow support
 * - Enables reactive form validation with debouncing
 * - No changes to underlying swift-java bindings
 *
 * Usage in ViewModel:
 * ```kotlin
 * val formValidation: StateFlow<FormValidationResult> = FormStateFlowBridge
 *     .observeListingFormValidation(titleFlow, descriptionFlow, quantityFlow)
 *     .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FormValidationResult.empty())
 * ```
 */
@OptIn(FlowPreview::class)
object FormStateFlowBridge {

    /**
     * Default debounce delay for form validation (milliseconds).
     */
    const val DEFAULT_DEBOUNCE_MS = 300L

    // ========================================================================
    // Listing Form Validation Flows
    // ========================================================================

    /**
     * Observe listing form validation reactively.
     *
     * @param titleFlow Flow of title text changes
     * @param descriptionFlow Flow of description text changes
     * @param quantityFlow Flow of quantity text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of FormValidationResult
     */
    fun observeListingFormValidation(
        titleFlow: Flow<String>,
        descriptionFlow: Flow<String>,
        quantityFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<FormValidationResult> = combine(
        titleFlow.debounce(debounceMs).distinctUntilChanged(),
        descriptionFlow.debounce(debounceMs).distinctUntilChanged(),
        quantityFlow.debounce(debounceMs).distinctUntilChanged()
    ) { title, description, quantity ->
        FormStateBridge.validateListing(title, description, quantity)
    }

    /**
     * Observe listing form validation with default quantity.
     *
     * @param titleFlow Flow of title text changes
     * @param descriptionFlow Flow of description text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of FormValidationResult
     */
    fun observeListingFormValidation(
        titleFlow: Flow<String>,
        descriptionFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<FormValidationResult> = combine(
        titleFlow.debounce(debounceMs).distinctUntilChanged(),
        descriptionFlow.debounce(debounceMs).distinctUntilChanged()
    ) { title, description ->
        FormStateBridge.validateListing(title, description, "1")
    }

    // ========================================================================
    // Profile Form Validation Flows
    // ========================================================================

    /**
     * Observe profile form validation reactively.
     *
     * @param displayNameFlow Flow of display name text changes
     * @param bioFlow Flow of bio text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of FormValidationResult
     */
    fun observeProfileFormValidation(
        displayNameFlow: Flow<String>,
        bioFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<FormValidationResult> = combine(
        displayNameFlow.debounce(debounceMs).distinctUntilChanged(),
        bioFlow.debounce(debounceMs).distinctUntilChanged()
    ) { displayName, bio ->
        FormStateBridge.validateProfile(displayName, bio)
    }

    // ========================================================================
    // Review Form Validation Flows
    // ========================================================================

    /**
     * Observe review form validation reactively.
     *
     * @param ratingFlow Flow of rating value (as string)
     * @param commentFlow Flow of comment text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of FormValidationResult
     */
    fun observeReviewFormValidation(
        ratingFlow: Flow<String>,
        commentFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<FormValidationResult> = combine(
        ratingFlow.distinctUntilChanged(),
        commentFlow.debounce(debounceMs).distinctUntilChanged()
    ) { rating, comment ->
        FormStateBridge.validateReview(rating, comment)
    }

    /**
     * Observe review form validation with integer rating.
     *
     * @param ratingFlow Flow of rating value (as Int)
     * @param commentFlow Flow of comment text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of FormValidationResult
     */
    @JvmName("observeReviewFormValidationInt")
    fun observeReviewFormValidationWithIntRating(
        ratingFlow: Flow<Int>,
        commentFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<FormValidationResult> = combine(
        ratingFlow.map { it.toString() }.distinctUntilChanged(),
        commentFlow.debounce(debounceMs).distinctUntilChanged()
    ) { rating, comment ->
        FormStateBridge.validateReview(rating, comment)
    }

    // ========================================================================
    // Forum Post Form Validation Flows
    // ========================================================================

    /**
     * Observe forum post form validation reactively.
     *
     * @param titleFlow Flow of title text changes
     * @param contentFlow Flow of content text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of FormValidationResult
     */
    fun observeForumPostFormValidation(
        titleFlow: Flow<String>,
        contentFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<FormValidationResult> = combine(
        titleFlow.debounce(debounceMs).distinctUntilChanged(),
        contentFlow.debounce(debounceMs).distinctUntilChanged()
    ) { title, content ->
        FormStateBridge.validateForumPost(title, content)
    }

    // ========================================================================
    // Single Field Validation Flows
    // ========================================================================

    /**
     * Observe single field validation reactively.
     *
     * @param fieldValueFlow Flow of field value changes
     * @param fieldName The name of the field to validate
     * @param fieldType The type of field validation to apply
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of field error or null if valid
     */
    fun observeFieldValidation(
        fieldValueFlow: Flow<String>,
        fieldName: String,
        fieldType: String,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<String?> = fieldValueFlow
        .debounce(debounceMs)
        .distinctUntilChanged()
        .map { value ->
            val result = FormStateBridge.validateField(fieldName, value, fieldType)
            result.firstError
        }

    // ========================================================================
    // Utility Functions
    // ========================================================================

    /**
     * Check if form is valid reactively.
     *
     * @param validationFlow Flow of FormValidationResult
     * @return Flow of Boolean indicating validity
     */
    fun observeFormValidity(
        validationFlow: Flow<FormValidationResult>
    ): Flow<Boolean> = validationFlow.map { it.isValid }

    /**
     * Extract all errors from validation flow.
     *
     * @param validationFlow Flow of FormValidationResult
     * @return Flow of all error messages
     */
    fun observeAllErrors(
        validationFlow: Flow<FormValidationResult>
    ): Flow<List<String>> = validationFlow.map { it.allErrors }

    /**
     * Extract field errors from validation flow.
     *
     * @param validationFlow Flow of FormValidationResult
     * @return Flow of field name to error messages map
     */
    fun observeFieldErrors(
        validationFlow: Flow<FormValidationResult>
    ): Flow<Map<String, List<String>>> = validationFlow.map { it.fieldErrors }
}
