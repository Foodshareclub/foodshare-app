package com.foodshare.core.forms

import com.foodshare.swift.generated.FormValidationEngine as SwiftFormValidationEngine
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.swift.swiftkit.core.SwiftArena
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Form state machine management.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for form state machines
 * - Field validation, state transitions are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - State machine for form lifecycle
 * - Field validation with error tracking
 * - Draft autosave and restoration
 *
 * Example:
 *   val formState = FormStateBridge.createMachine()
 *   formState.registerField("title", "")
 *   formState.updateField("title", "Fresh Bread")
 *   val validation = formState.validateListingForm()
 *   if (!validation.isValid) {
 *       showErrors(validation.fieldErrors)
 *   }
 */
object FormStateBridge {

    internal val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    // SwiftArena for memory management of Swift objects
    private val arena: SwiftArena by lazy { SwiftArena.ofAuto() }

    // ========================================================================
    // Swift-backed Validation (Cross-Platform Consistent)
    // ========================================================================

    /**
     * Validate listing form using Swift engine for cross-platform consistency.
     */
    fun validateListing(title: String, description: String, quantity: String): FormValidationResult {
        val swiftResult = SwiftFormValidationEngine.validateListingForm(title, description, quantity, arena)
        return FormValidationResult(
            isValid = swiftResult.isValid,
            fieldErrors = parseFieldErrors(swiftResult.fieldErrors),
            allErrors = parseAllErrors(swiftResult.allErrors)
        )
    }

    /**
     * Validate profile form using Swift engine for cross-platform consistency.
     */
    fun validateProfile(displayName: String, bio: String): FormValidationResult {
        val swiftResult = SwiftFormValidationEngine.validateProfileForm(displayName, bio, arena)
        return FormValidationResult(
            isValid = swiftResult.isValid,
            fieldErrors = parseFieldErrors(swiftResult.fieldErrors),
            allErrors = parseAllErrors(swiftResult.allErrors)
        )
    }

    /**
     * Validate review form using Swift engine for cross-platform consistency.
     */
    fun validateReview(rating: String, comment: String): FormValidationResult {
        val swiftResult = SwiftFormValidationEngine.validateReviewForm(rating, comment, arena)
        return FormValidationResult(
            isValid = swiftResult.isValid,
            fieldErrors = parseFieldErrors(swiftResult.fieldErrors),
            allErrors = parseAllErrors(swiftResult.allErrors)
        )
    }

    /**
     * Validate forum post form using Swift engine for cross-platform consistency.
     */
    fun validateForumPost(title: String, content: String): FormValidationResult {
        val swiftResult = SwiftFormValidationEngine.validateForumPostForm(title, content, arena)
        return FormValidationResult(
            isValid = swiftResult.isValid,
            fieldErrors = parseFieldErrors(swiftResult.fieldErrors),
            allErrors = parseAllErrors(swiftResult.allErrors)
        )
    }

    /**
     * Validate a single field using Swift engine.
     */
    fun validateField(fieldId: String, value: String, formType: String): FieldValidationResult {
        val swiftResult = SwiftFormValidationEngine.validateField(fieldId, value, formType, arena)
        return FieldValidationResult(
            isValid = swiftResult.isValid,
            errors = parseAllErrors(swiftResult.errors),
            firstError = swiftResult.firstError.takeIf { it.isNotEmpty() }
        )
    }

    /**
     * Get validation constants from Swift engine.
     */
    object ValidationConstants {
        val listingMinTitleLength: Int by lazy { SwiftFormValidationEngine.getListingMinTitleLength() }
        val listingMaxTitleLength: Int by lazy { SwiftFormValidationEngine.getListingMaxTitleLength() }
        val listingMinDescriptionLength: Int by lazy { SwiftFormValidationEngine.getListingMinDescriptionLength() }
        val listingMaxDescriptionLength: Int by lazy { SwiftFormValidationEngine.getListingMaxDescriptionLength() }
    }

    // Parse JSON field errors from Swift: {"field": ["error1", "error2"]}
    private fun parseFieldErrors(jsonStr: String): Map<String, List<String>> {
        return try {
            json.decodeFromString<Map<String, List<String>>>(jsonStr)
        } catch (e: Exception) {
            emptyMap()
        }
    }

    // Parse JSON error array from Swift: ["error1", "error2"]
    private fun parseAllErrors(jsonStr: String): List<String> {
        return try {
            json.decodeFromString<List<String>>(jsonStr)
        } catch (e: Exception) {
            emptyList()
        }
    }

    // ========================================================================
    // State Machine Creation
    // ========================================================================

    /**
     * Create a new form state machine.
     */
    fun createMachine(): FormMachineState {
        val snapshot = MachineSnapshot(
            state = FormState.INITIAL.value,
            context = FormContext()
        )
        return FormMachineState(json.encodeToString(snapshot))
    }

    /**
     * Restore a form from a saved draft.
     */
    fun restoreFromDraft(draftJson: String): FormMachineState {
        return try {
            val draft = json.decodeFromString<FormDraft>(draftJson)

            // Convert draft fields to FormFieldState
            val fields = draft.fields.mapValues { (fieldId, value) ->
                FormFieldState(
                    fieldId = fieldId,
                    originalValue = value,
                    currentValue = value,
                    isDirty = false,
                    isValid = true
                )
            }

            val snapshot = MachineSnapshot(
                state = FormState.EDITING.value,
                context = FormContext(
                    fields = fields,
                    isDirty = false
                )
            )
            FormMachineState(json.encodeToString(snapshot))
        } catch (e: Exception) {
            FormMachineState.empty()
        }
    }

    // ========================================================================
    // Form Types
    // ========================================================================

    enum class FormType(val value: String) {
        CREATE_LISTING("create_listing"),
        EDIT_LISTING("edit_listing"),
        CREATE_PROFILE("create_profile"),
        EDIT_PROFILE("edit_profile"),
        CREATE_REVIEW("create_review"),
        CREATE_FORUM_POST("create_forum_post"),
        CREATE_FORUM_COMMENT("create_forum_comment"),
        REPORT_CONTENT("report_content")
    }

    enum class FormEvent(val value: String) {
        START_EDITING("start_editing"),
        FIELD_CHANGED("field_changed"),
        VALIDATE("validate"),
        VALIDATION_SUCCEEDED("validation_succeeded"),
        VALIDATION_FAILED("validation_failed"),
        SUBMIT("submit"),
        SUBMIT_SUCCEEDED("submit_succeeded"),
        SUBMIT_FAILED("submit_failed"),
        RESET("reset"),
        RETRY("retry")
    }

    enum class FormState(val value: String) {
        INITIAL("initial"),
        EDITING("editing"),
        VALIDATING("validating"),
        SUBMITTING("submitting"),
        SUCCESS("success"),
        ERROR("error");

        val isInteractive: Boolean
            get() = this in listOf(INITIAL, EDITING, ERROR)

        val canSubmit: Boolean
            get() = this in listOf(EDITING, ERROR)

        companion object {
            fun fromValue(value: String): FormState =
                entries.find { it.value == value } ?: INITIAL
        }
    }
}

/**
 * Represents the current state of a form.
 * Local Kotlin implementation of form state machine.
 */
class FormMachineState(private var machineJson: String) {

    companion object {
        fun empty(): FormMachineState = FormMachineState("{\"state\":\"initial\",\"context\":{}}")
    }

    /**
     * Get the current form state.
     */
    val currentState: FormStateBridge.FormState
        get() {
            val snapshot = parseSnapshot()
            return FormStateBridge.FormState.fromValue(snapshot?.state ?: "initial")
        }

    /**
     * Check if form is dirty (has unsaved changes).
     */
    val isDirty: Boolean
        get() = parseSnapshot()?.context?.isDirty ?: false

    /**
     * Check if form is valid (no errors).
     */
    val isValid: Boolean
        get() = parseSnapshot()?.context?.let { context ->
            context.errors.isEmpty() || context.errors.values.all { it.isEmpty() }
        } ?: true

    /**
     * Check if the form can be submitted.
     */
    val canSubmit: Boolean
        get() = currentState.canSubmit && isValid

    /**
     * Get the raw JSON representation.
     */
    fun toJson(): String = machineJson

    // ========================================================================
    // Field Management
    // ========================================================================

    /**
     * Register a field with an initial value.
     */
    fun registerField(fieldId: String, initialValue: String = "") {
        val snapshot = parseSnapshot() ?: return
        val newField = FormFieldState(
            fieldId = fieldId,
            originalValue = initialValue,
            currentValue = initialValue,
            isDirty = false,
            isValid = true
        )
        val newFields = snapshot.context.fields.toMutableMap()
        newFields[fieldId] = newField

        val newSnapshot = snapshot.copy(
            context = snapshot.context.copy(fields = newFields)
        )
        machineJson = FormStateBridge.json.encodeToString(newSnapshot)
    }

    /**
     * Update a field value.
     */
    fun updateField(fieldId: String, value: String) {
        val snapshot = parseSnapshot() ?: return
        val existingField = snapshot.context.fields[fieldId] ?: FormFieldState(
            fieldId = fieldId,
            originalValue = "",
            currentValue = ""
        )

        val updatedField = existingField.copy(
            currentValue = value,
            isDirty = value != existingField.originalValue,
            isTouched = true
        )

        val newFields = snapshot.context.fields.toMutableMap()
        newFields[fieldId] = updatedField

        val anyDirty = newFields.values.any { it.isDirty }
        val newState = if (snapshot.state == "initial") "editing" else snapshot.state

        val newSnapshot = snapshot.copy(
            state = newState,
            context = snapshot.context.copy(
                fields = newFields,
                isDirty = anyDirty
            )
        )
        machineJson = FormStateBridge.json.encodeToString(newSnapshot)
    }

    /**
     * Get the current value of a field.
     */
    fun getFieldValue(fieldId: String): String? {
        val snapshot = parseSnapshot()
        return snapshot?.context?.fields?.get(fieldId)?.currentValue
    }

    /**
     * Get errors for a specific field.
     */
    fun getFieldErrors(fieldId: String): List<String> {
        val snapshot = parseSnapshot()
        return snapshot?.context?.errors?.get(fieldId) ?: emptyList()
    }

    /**
     * Check if a field has errors.
     */
    fun hasFieldErrors(fieldId: String): Boolean {
        return getFieldErrors(fieldId).isNotEmpty()
    }

    /**
     * Get the first error for a field.
     */
    fun getFirstFieldError(fieldId: String): String? {
        return getFieldErrors(fieldId).firstOrNull()
    }

    // ========================================================================
    // Events
    // ========================================================================

    /**
     * Send an event to the state machine.
     */
    fun send(event: FormStateBridge.FormEvent): FormTransitionResult {
        val snapshot = parseSnapshot() ?: return FormTransitionResult(
            previousState = currentState,
            currentState = currentState,
            transitioned = false
        )

        val previousState = FormStateBridge.FormState.fromValue(snapshot.state)

        // State machine transitions
        val newState = when (event) {
            FormStateBridge.FormEvent.START_EDITING -> FormStateBridge.FormState.EDITING
            FormStateBridge.FormEvent.FIELD_CHANGED -> FormStateBridge.FormState.EDITING
            FormStateBridge.FormEvent.VALIDATE -> FormStateBridge.FormState.VALIDATING
            FormStateBridge.FormEvent.VALIDATION_SUCCEEDED -> FormStateBridge.FormState.EDITING
            FormStateBridge.FormEvent.VALIDATION_FAILED -> FormStateBridge.FormState.ERROR
            FormStateBridge.FormEvent.SUBMIT -> FormStateBridge.FormState.SUBMITTING
            FormStateBridge.FormEvent.SUBMIT_SUCCEEDED -> FormStateBridge.FormState.SUCCESS
            FormStateBridge.FormEvent.SUBMIT_FAILED -> FormStateBridge.FormState.ERROR
            FormStateBridge.FormEvent.RESET -> FormStateBridge.FormState.INITIAL
            FormStateBridge.FormEvent.RETRY -> FormStateBridge.FormState.EDITING
        }

        val newContext = if (event == FormStateBridge.FormEvent.RESET) {
            FormContext()
        } else {
            snapshot.context
        }

        val newSnapshot = snapshot.copy(
            state = newState.value,
            context = newContext
        )
        machineJson = FormStateBridge.json.encodeToString(newSnapshot)

        return FormTransitionResult(
            previousState = previousState,
            currentState = newState,
            transitioned = previousState != newState
        )
    }

    /**
     * Reset the form to initial state.
     */
    fun reset() {
        send(FormStateBridge.FormEvent.RESET)
    }

    // ========================================================================
    // Validation (Swift-backed for cross-platform consistency)
    // ========================================================================

    /**
     * Validate as a listing form using Swift engine.
     */
    fun validateListingForm(): FormValidationResult {
        val snapshot = parseSnapshot() ?: return FormValidationResult(isValid = false, error = "Invalid form state")
        val fields = snapshot.context.fields

        val title = fields["title"]?.currentValue ?: ""
        val description = fields["description"]?.currentValue ?: ""
        val quantity = fields["quantity"]?.currentValue ?: "1"

        return FormStateBridge.validateListing(title, description, quantity)
    }

    /**
     * Validate as a profile form using Swift engine.
     */
    fun validateProfileForm(): FormValidationResult {
        val snapshot = parseSnapshot() ?: return FormValidationResult(isValid = false, error = "Invalid form state")
        val fields = snapshot.context.fields

        val displayName = fields["displayName"]?.currentValue ?: fields["display_name"]?.currentValue ?: ""
        val bio = fields["bio"]?.currentValue ?: ""

        return FormStateBridge.validateProfile(displayName, bio)
    }

    /**
     * Validate as a review form using Swift engine.
     */
    fun validateReviewForm(): FormValidationResult {
        val snapshot = parseSnapshot() ?: return FormValidationResult(isValid = false, error = "Invalid form state")
        val fields = snapshot.context.fields

        val rating = fields["rating"]?.currentValue ?: "0"
        val comment = fields["comment"]?.currentValue ?: ""

        return FormStateBridge.validateReview(rating, comment)
    }

    /**
     * Validate as a forum post form using Swift engine.
     */
    fun validateForumPostForm(): FormValidationResult {
        val snapshot = parseSnapshot() ?: return FormValidationResult(isValid = false, error = "Invalid form state")
        val fields = snapshot.context.fields

        val title = fields["title"]?.currentValue ?: ""
        val content = fields["content"]?.currentValue ?: ""

        return FormStateBridge.validateForumPost(title, content)
    }

    // ========================================================================
    // Draft Management
    // ========================================================================

    /**
     * Create a draft from current form state.
     */
    fun createDraft(formType: FormStateBridge.FormType): FormDraft? {
        val snapshot = parseSnapshot() ?: return null

        // Extract field values
        val fieldValues = snapshot.context.fields.mapValues { (_, field) ->
            field.currentValue
        }

        if (fieldValues.isEmpty()) return null

        val now = Instant.now()
        val formatter = DateTimeFormatter.ISO_INSTANT

        return FormDraft(
            id = UUID.randomUUID().toString(),
            formType = formType.value,
            fields = fieldValues,
            createdAt = formatter.format(now),
            updatedAt = formatter.format(now),
            expiresAt = formatter.format(now.plus(7, ChronoUnit.DAYS))  // 7 day expiry
        )
    }

    /**
     * Check if auto-save should trigger.
     */
    fun shouldAutoSave(lastSaveTimeMs: Long): Boolean {
        val snapshot = parseSnapshot() ?: return false

        // Only auto-save if dirty
        if (!snapshot.context.isDirty) return false

        // Auto-save every 30 seconds
        val autoSaveIntervalMs = 30_000
        val timeSinceLastSave = System.currentTimeMillis() - lastSaveTimeMs

        return timeSinceLastSave >= autoSaveIntervalMs
    }

    // ========================================================================
    // Private Helpers
    // ========================================================================

    private fun parseSnapshot(): MachineSnapshot? {
        return try {
            FormStateBridge.json.decodeFromString<MachineSnapshot>(machineJson)
        } catch (e: Exception) {
            null
        }
    }
}

// ========================================================================
// Data Classes
// ========================================================================

@Serializable
data class FormTransitionResult(
    val previousState: FormStateBridge.FormState,
    val currentState: FormStateBridge.FormState,
    val transitioned: Boolean
)

@Serializable
data class FormValidationResult(
    val isValid: Boolean = false,
    val fieldErrors: Map<String, List<String>> = emptyMap(),
    val allErrors: List<String> = emptyList(),
    val error: String? = null
) {
    val firstError: String?
        get() = allErrors.firstOrNull() ?: error

    val errorCount: Int
        get() = allErrors.size

    fun errorsFor(fieldId: String): List<String> = fieldErrors[fieldId] ?: emptyList()

    fun hasErrorsFor(fieldId: String): Boolean = errorsFor(fieldId).isNotEmpty()
}

@Serializable
data class FormDraft(
    val id: String,
    val formType: String,
    val fields: Map<String, String>,
    val createdAt: String,
    val updatedAt: String,
    val expiresAt: String,
    val metadata: Map<String, String> = emptyMap()
)

@Serializable
data class FormFieldState(
    val fieldId: String,
    val fieldType: String = "text",
    val originalValue: String = "",
    val currentValue: String = "",
    val isDirty: Boolean = false,
    val isValid: Boolean = true,
    val isTouched: Boolean = false,
    val isFocused: Boolean = false,
    val errors: List<String> = emptyList(),
    val metadata: Map<String, String> = emptyMap()
)

@Serializable
data class FormContext(
    val fields: Map<String, FormFieldState> = emptyMap(),
    val errors: Map<String, List<String>> = emptyMap(),
    val isDirty: Boolean = false,
    val lastValidatedAt: String? = null,
    val submissionError: String? = null,
    val submissionId: String? = null
)

@Serializable
internal data class MachineSnapshot(
    val state: String,
    val context: FormContext
)

@Serializable
internal data class EventResultWrapper(
    val result: TransitionResultData? = null,
    val machine: MachineSnapshot? = null,
    val error: String? = null
)

@Serializable
internal data class TransitionResultData(
    val previousState: String,
    val currentState: String,
    val transitioned: Boolean
)

/**
 * Single field validation result.
 */
@Serializable
data class FieldValidationResult(
    val isValid: Boolean = true,
    val errors: List<String> = emptyList(),
    val firstError: String? = null
) {
    val errorCount: Int
        get() = errors.size

    val hasErrors: Boolean
        get() = errors.isNotEmpty()
}
