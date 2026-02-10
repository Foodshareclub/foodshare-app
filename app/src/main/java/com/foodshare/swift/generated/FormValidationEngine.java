package com.foodshare.swift.generated;

import org.swift.swiftkit.core.SwiftArena;

/**
 * Generated Java class for Swift FormValidationEngine.
 * Provides form validation with cross-platform consistent rules.
 */
@SuppressWarnings("unused")
public final class FormValidationEngine {

    static final String LIB_NAME = "FoodshareCore";
    private static volatile boolean LIBS_INITIALIZED = false;

    private FormValidationEngine() {
        // Static utility class
    }

    static boolean initializeLibs() {
        if (!LIBS_INITIALIZED) {
            synchronized (FormValidationEngine.class) {
                if (!LIBS_INITIALIZED) {
                    System.loadLibrary(LIB_NAME);
                    LIBS_INITIALIZED = true;
                }
            }
        }
        return true;
    }

    static {
        initializeLibs();
    }

    // ========================================================================
    // Form Validation Methods
    // ========================================================================

    /**
     * Validate a listing form.
     *
     * @param title Listing title
     * @param description Listing description
     * @param quantity Listing quantity (as string)
     * @param arena SwiftArena for memory management
     * @return FormValidationResult
     */
    public static FormValidationResult validateListingForm(
            String title,
            String description,
            String quantity,
            SwiftArena arena
    ) {
        long resultPtr = $validateListingForm(title, description, quantity);
        return FormValidationResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $validateListingForm(String title, String description, String quantity);

    /**
     * Validate a profile form.
     *
     * @param displayName User's display name
     * @param bio User's bio (optional)
     * @param arena SwiftArena for memory management
     * @return FormValidationResult
     */
    public static FormValidationResult validateProfileForm(
            String displayName,
            String bio,
            SwiftArena arena
    ) {
        long resultPtr = $validateProfileForm(displayName, bio);
        return FormValidationResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $validateProfileForm(String displayName, String bio);

    /**
     * Validate a review form.
     *
     * @param rating Rating value (as string, 1-5)
     * @param comment Review comment (optional)
     * @param arena SwiftArena for memory management
     * @return FormValidationResult
     */
    public static FormValidationResult validateReviewForm(
            String rating,
            String comment,
            SwiftArena arena
    ) {
        long resultPtr = $validateReviewForm(rating, comment);
        return FormValidationResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $validateReviewForm(String rating, String comment);

    /**
     * Validate a forum post form.
     *
     * @param title Post title
     * @param content Post content
     * @param arena SwiftArena for memory management
     * @return FormValidationResult
     */
    public static FormValidationResult validateForumPostForm(
            String title,
            String content,
            SwiftArena arena
    ) {
        long resultPtr = $validateForumPostForm(title, content);
        return FormValidationResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $validateForumPostForm(String title, String content);

    /**
     * Validate a single field.
     *
     * @param fieldId Field identifier
     * @param value Field value
     * @param formType Form type (listing, profile, review, forum)
     * @param arena SwiftArena for memory management
     * @return FieldValidationResult
     */
    public static FieldValidationResult validateField(
            String fieldId,
            String value,
            String formType,
            SwiftArena arena
    ) {
        long resultPtr = $validateField(fieldId, value, formType);
        return FieldValidationResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $validateField(String fieldId, String value, String formType);

    // ========================================================================
    // Validation Constants
    // ========================================================================

    /**
     * Get listing minimum title length.
     */
    public static int getListingMinTitleLength() {
        return $getListingMinTitleLength();
    }

    private static native int $getListingMinTitleLength();

    /**
     * Get listing maximum title length.
     */
    public static int getListingMaxTitleLength() {
        return $getListingMaxTitleLength();
    }

    private static native int $getListingMaxTitleLength();

    /**
     * Get listing minimum description length.
     */
    public static int getListingMinDescriptionLength() {
        return $getListingMinDescriptionLength();
    }

    private static native int $getListingMinDescriptionLength();

    /**
     * Get listing maximum description length.
     */
    public static int getListingMaxDescriptionLength() {
        return $getListingMaxDescriptionLength();
    }

    private static native int $getListingMaxDescriptionLength();
}
