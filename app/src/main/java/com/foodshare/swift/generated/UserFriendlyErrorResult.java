package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift UserFriendlyErrorResult.
 * Contains user-friendly error display information.
 */
@SuppressWarnings("unused")
public final class UserFriendlyErrorResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = ErrorMappingEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private UserFriendlyErrorResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static UserFriendlyErrorResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new UserFriendlyErrorResult(selfPointer, swiftArena);
    }

    @Override
    public long $memoryAddress() {
        return this.selfPointer;
    }

    @Override
    public AtomicBoolean $statusDestroyedFlag() {
        return this.$state$destroyed;
    }

    // ========================================================================
    // Property Accessors
    // ========================================================================

    public String getTitle() {
        return $getTitle(this.selfPointer);
    }

    private static native String $getTitle(long selfPointer);

    public String getMessage() {
        return $getMessage(this.selfPointer);
    }

    private static native String $getMessage(long selfPointer);

    public String getSuggestion() {
        return $getSuggestion(this.selfPointer);
    }

    private static native String $getSuggestion(long selfPointer);

    public String getIcon() {
        return $getIcon(this.selfPointer);
    }

    private static native String $getIcon(long selfPointer);

    public String getStyle() {
        return $getStyle(this.selfPointer);
    }

    private static native String $getStyle(long selfPointer);

    public boolean isDismissable() {
        return $getDismissable(this.selfPointer);
    }

    private static native boolean $getDismissable(long selfPointer);

    public boolean shouldShowRetry() {
        return $getShowRetry(this.selfPointer);
    }

    private static native boolean $getShowRetry(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> UserFriendlyErrorResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return UserFriendlyErrorResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "UserFriendlyErrorResult{" +
                "title='" + getTitle() + '\'' +
                ", message='" + getMessage() + '\'' +
                ", icon='" + getIcon() + '\'' +
                ", dismissable=" + isDismissable() +
                ", showRetry=" + shouldShowRetry() +
                '}';
    }
}
