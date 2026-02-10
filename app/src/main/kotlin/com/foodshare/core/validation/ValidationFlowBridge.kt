package com.foodshare.core.validation

import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map

/**
 * Flow-based reactive wrappers for ValidationBridge.
 *
 * Architecture (Frameo pattern):
 * - Wraps ValidationBridge with Kotlin Flow support
 * - Enables reactive UI validation with debouncing
 * - No changes to underlying swift-java bindings
 *
 * Usage in ViewModel:
 * ```kotlin
 * val validationResult: StateFlow<ValidationResult> = ValidationFlowBridge
 *     .observeListingValidation(titleFlow, descriptionFlow)
 *     .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), ValidationResult.empty())
 * ```
 */
@OptIn(FlowPreview::class)
object ValidationFlowBridge {

    /**
     * Default debounce delay for validation (milliseconds).
     * Prevents excessive validation calls during rapid typing.
     */
    const val DEFAULT_DEBOUNCE_MS = 300L

    // ========================================================================
    // Listing Validation Flows
    // ========================================================================

    /**
     * Observe listing validation reactively.
     *
     * @param titleFlow Flow of title text changes
     * @param descriptionFlow Flow of description text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of ValidationResult
     */
    fun observeListingValidation(
        titleFlow: Flow<String>,
        descriptionFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<ValidationResult> = combine(
        titleFlow.debounce(debounceMs).distinctUntilChanged(),
        descriptionFlow.debounce(debounceMs).distinctUntilChanged()
    ) { title, description ->
        ValidationBridge.validateListing(title, description)
    }

    /**
     * Observe listing validation with quantity.
     *
     * @param titleFlow Flow of title text changes
     * @param descriptionFlow Flow of description text changes
     * @param quantityFlow Flow of quantity changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of ValidationResult
     */
    fun observeListingValidation(
        titleFlow: Flow<String>,
        descriptionFlow: Flow<String>,
        quantityFlow: Flow<Int>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<ValidationResult> = combine(
        titleFlow.debounce(debounceMs).distinctUntilChanged(),
        descriptionFlow.debounce(debounceMs).distinctUntilChanged(),
        quantityFlow.distinctUntilChanged()
    ) { title, description, quantity ->
        ValidationBridge.validateListing(title, description, quantity)
    }

    /**
     * Observe title validation only.
     *
     * @param titleFlow Flow of title text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of error message or null if valid
     */
    fun observeTitleValidation(
        titleFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<String?> = titleFlow
        .debounce(debounceMs)
        .distinctUntilChanged()
        .map { ValidationBridge.validateTitle(it) }

    /**
     * Observe description validation only.
     *
     * @param descriptionFlow Flow of description text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of error message or null if valid
     */
    fun observeDescriptionValidation(
        descriptionFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<String?> = descriptionFlow
        .debounce(debounceMs)
        .distinctUntilChanged()
        .map { ValidationBridge.validateDescription(it) }

    // ========================================================================
    // Profile Validation Flows
    // ========================================================================

    /**
     * Observe profile validation reactively.
     *
     * @param nicknameFlow Flow of nickname text changes
     * @param bioFlow Flow of bio text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of ValidationResult
     */
    fun observeProfileValidation(
        nicknameFlow: Flow<String?>,
        bioFlow: Flow<String?>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<ValidationResult> = combine(
        nicknameFlow.debounce(debounceMs).distinctUntilChanged(),
        bioFlow.debounce(debounceMs).distinctUntilChanged()
    ) { nickname, bio ->
        ValidationBridge.validateProfile(nickname, bio)
    }

    /**
     * Observe nickname validation only.
     *
     * @param nicknameFlow Flow of nickname text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of error message or null if valid
     */
    fun observeNicknameValidation(
        nicknameFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<String?> = nicknameFlow
        .debounce(debounceMs)
        .distinctUntilChanged()
        .map { ValidationBridge.validateNickname(it) }

    /**
     * Observe bio validation only.
     *
     * @param bioFlow Flow of bio text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of error message or null if valid
     */
    fun observeBioValidation(
        bioFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<String?> = bioFlow
        .debounce(debounceMs)
        .distinctUntilChanged()
        .map { ValidationBridge.validateBio(it) }

    // ========================================================================
    // Review Validation Flows
    // ========================================================================

    /**
     * Observe review validation reactively.
     *
     * @param ratingFlow Flow of rating value changes
     * @param commentFlow Flow of comment text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of ValidationResult
     */
    fun observeReviewValidation(
        ratingFlow: Flow<Int>,
        commentFlow: Flow<String?>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<ValidationResult> = combine(
        ratingFlow.distinctUntilChanged(),
        commentFlow.debounce(debounceMs).distinctUntilChanged()
    ) { rating, comment ->
        ValidationBridge.validateReview(rating, comment)
    }

    // ========================================================================
    // Auth Validation Flows
    // ========================================================================

    /**
     * Observe email validation reactively.
     *
     * @param emailFlow Flow of email text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of error message or null if valid
     */
    fun observeEmailValidation(
        emailFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<String?> = emailFlow
        .debounce(debounceMs)
        .distinctUntilChanged()
        .map { ValidationBridge.validateEmail(it) }

    /**
     * Observe password validation reactively.
     *
     * @param passwordFlow Flow of password text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of error message or null if valid
     */
    fun observePasswordValidation(
        passwordFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<String?> = passwordFlow
        .debounce(debounceMs)
        .distinctUntilChanged()
        .map { ValidationBridge.validatePassword(it) }

    /**
     * Observe login form validation reactively.
     * Combines email and password validation.
     *
     * @param emailFlow Flow of email text changes
     * @param passwordFlow Flow of password text changes
     * @param debounceMs Debounce delay in milliseconds
     * @return Flow of ValidationResult
     */
    fun observeLoginValidation(
        emailFlow: Flow<String>,
        passwordFlow: Flow<String>,
        debounceMs: Long = DEFAULT_DEBOUNCE_MS
    ): Flow<ValidationResult> = combine(
        emailFlow.debounce(debounceMs).distinctUntilChanged(),
        passwordFlow.debounce(debounceMs).distinctUntilChanged()
    ) { email, password ->
        val errors = mutableListOf<ValidationError>()
        ValidationBridge.validateEmail(email)?.let { errors.add(ValidationError.Custom(it)) }
        ValidationBridge.validatePassword(password)?.let { errors.add(ValidationError.Custom(it)) }
        ValidationResult(isValid = errors.isEmpty(), errors = errors)
    }
}
