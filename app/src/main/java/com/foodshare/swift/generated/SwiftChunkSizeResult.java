package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift ChunkSizeResult.
 * Contains chunk size calculation results.
 */
@SuppressWarnings("unused")
public final class SwiftChunkSizeResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = BatchOperationsEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private SwiftChunkSizeResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static SwiftChunkSizeResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new SwiftChunkSizeResult(selfPointer, swiftArena);
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

    public int getRecommendedSize() {
        return $getRecommendedSize(this.selfPointer);
    }

    private static native int $getRecommendedSize(long selfPointer);

    public int getChunkCount() {
        return $getChunkCount(this.selfPointer);
    }

    private static native int $getChunkCount(long selfPointer);

    public int getTotalItems() {
        return $getTotalItems(this.selfPointer);
    }

    private static native int $getTotalItems(long selfPointer);

    public String getReason() {
        return $getReason(this.selfPointer);
    }

    private static native String $getReason(long selfPointer);

    public boolean isSingleChunk() {
        return $getIsSingleChunk(this.selfPointer);
    }

    private static native boolean $getIsSingleChunk(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> SwiftChunkSizeResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return SwiftChunkSizeResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "SwiftChunkSizeResult{" +
                "recommendedSize=" + getRecommendedSize() +
                ", chunkCount=" + getChunkCount() +
                ", totalItems=" + getTotalItems() +
                ", reason='" + getReason() + '\'' +
                ", isSingleChunk=" + isSingleChunk() +
                '}';
    }
}
