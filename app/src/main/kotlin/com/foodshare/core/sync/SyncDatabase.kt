package com.foodshare.core.sync

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Delete
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverter
import androidx.room.TypeConverters
import androidx.room.Update
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Room database for offline sync functionality.
 *
 * Stores:
 * - Sync version tracking
 * - Pending operations queue
 * - Cached listings and profiles
 *
 * SYNC: Schema mirrors Swift CoreData model
 */
@Database(
    entities = [
        SyncVersion::class,
        PendingOperation::class,
        CachedListing::class,
        CachedProfile::class,
        SyncConflict::class
    ],
    version = 1,
    exportSchema = true
)
@TypeConverters(SyncConverters::class)
abstract class SyncDatabase : RoomDatabase() {

    abstract fun syncVersionDao(): SyncVersionDao
    abstract fun pendingOperationDao(): PendingOperationDao
    abstract fun cachedListingDao(): CachedListingDao
    abstract fun cachedProfileDao(): CachedProfileDao
    abstract fun syncConflictDao(): SyncConflictDao

    companion object {
        private const val DATABASE_NAME = "foodshare_sync.db"

        @Volatile
        private var instance: SyncDatabase? = null

        fun getInstance(context: Context): SyncDatabase {
            return instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    SyncDatabase::class.java,
                    DATABASE_NAME
                )
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { instance = it }
            }
        }
    }
}

// ============================================================================
// Entities
// ============================================================================

/**
 * Tracks sync version for delta sync.
 */
@Entity(tableName = "sync_versions")
data class SyncVersion(
    @PrimaryKey val tableName: String,
    val version: Long,
    val lastSyncAt: Long,
    val lastSyncStatus: String = "success"
)

/**
 * Types of pending operations.
 */
enum class OperationType {
    CREATE,
    UPDATE,
    DELETE
}

/**
 * Pending operation to be synced when online.
 */
@Entity(tableName = "pending_operations")
data class PendingOperation(
    @PrimaryKey val id: String,
    val type: OperationType,
    val tableName: String,
    val recordId: String?,
    val payload: String,  // JSON
    val createdAt: Long,
    val retryCount: Int = 0,
    val lastError: String? = null,
    val idempotencyKey: String
)

/**
 * Cached food listing for offline access.
 */
@Entity(tableName = "cached_listings")
data class CachedListing(
    @PrimaryKey val id: Int,
    val profileId: String,
    val postName: String,
    val postDescription: String?,
    val postType: String,
    val postAddress: String?,
    val latitude: Double?,
    val longitude: Double?,
    val images: String?,  // JSON array
    val isActive: Boolean,
    val isArranged: Boolean,
    val createdAt: String?,  // Nullable to match DTO
    val updatedAt: String?,
    val cachedAt: Long = System.currentTimeMillis(),
    val syncVersion: Long = 0
)

/**
 * Cached user profile for offline access.
 */
@Entity(tableName = "cached_profiles")
data class CachedProfile(
    @PrimaryKey val id: String,
    val email: String?,
    val nickname: String?,
    val avatarUrl: String?,
    val bio: String?,
    val createdAt: String,
    val cachedAt: Long = System.currentTimeMillis(),
    val syncVersion: Long = 0
)

/**
 * Sync conflict requiring resolution.
 */
@Entity(tableName = "sync_conflicts")
data class SyncConflict(
    @PrimaryKey val id: String,
    val tableName: String,
    val recordId: String,
    val localData: String,   // JSON
    val remoteData: String,  // JSON
    val conflictType: String,
    val detectedAt: Long,
    val resolvedAt: Long? = null,
    val resolution: String? = null
)

// ============================================================================
// DAOs
// ============================================================================

@Dao
interface SyncVersionDao {
    @Query("SELECT * FROM sync_versions WHERE tableName = :table")
    suspend fun getVersion(table: String): SyncVersion?

    @Query("SELECT * FROM sync_versions")
    fun observeAll(): Flow<List<SyncVersion>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(version: SyncVersion)

    @Query("UPDATE sync_versions SET version = :version, lastSyncAt = :syncAt WHERE tableName = :table")
    suspend fun updateVersion(table: String, version: Long, syncAt: Long)

    @Query("DELETE FROM sync_versions")
    suspend fun clearAll()
}

@Dao
interface PendingOperationDao {
    @Query("SELECT * FROM pending_operations ORDER BY createdAt ASC")
    suspend fun getAll(): List<PendingOperation>

    @Query("SELECT * FROM pending_operations ORDER BY createdAt ASC")
    fun observeAll(): Flow<List<PendingOperation>>

    @Query("SELECT COUNT(*) FROM pending_operations")
    fun observeCount(): Flow<Int>

    @Query("SELECT * FROM pending_operations WHERE tableName = :table ORDER BY createdAt ASC")
    suspend fun getForTable(table: String): List<PendingOperation>

    @Query("SELECT * FROM pending_operations WHERE retryCount < :maxRetries ORDER BY createdAt ASC LIMIT :limit")
    suspend fun getPendingWithRetryLimit(maxRetries: Int, limit: Int): List<PendingOperation>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(operation: PendingOperation)

    @Update
    suspend fun update(operation: PendingOperation)

    @Delete
    suspend fun delete(operation: PendingOperation)

    @Query("DELETE FROM pending_operations WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("UPDATE pending_operations SET retryCount = retryCount + 1, lastError = :error WHERE id = :id")
    suspend fun incrementRetry(id: String, error: String?)

    @Query("DELETE FROM pending_operations")
    suspend fun clearAll()
}

@Dao
interface CachedListingDao {
    @Query("SELECT * FROM cached_listings WHERE isActive = 1 ORDER BY createdAt DESC")
    suspend fun getAll(): List<CachedListing>

    @Query("SELECT * FROM cached_listings WHERE isActive = 1 ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<CachedListing>>

    @Query("SELECT * FROM cached_listings WHERE id = :id")
    suspend fun getById(id: Int): CachedListing?

    @Query("SELECT * FROM cached_listings WHERE profileId = :profileId ORDER BY createdAt DESC")
    suspend fun getByProfile(profileId: String): List<CachedListing>

    @Query("SELECT * FROM cached_listings WHERE syncVersion > :version")
    suspend fun getUpdatedSince(version: Long): List<CachedListing>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(listing: CachedListing)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(listings: List<CachedListing>)

    @Query("DELETE FROM cached_listings WHERE id = :id")
    suspend fun deleteById(id: Int)

    @Query("DELETE FROM cached_listings WHERE cachedAt < :cutoff")
    suspend fun deleteOlderThan(cutoff: Long)

    @Query("DELETE FROM cached_listings")
    suspend fun clearAll()
}

@Dao
interface CachedProfileDao {
    @Query("SELECT * FROM cached_profiles")
    suspend fun getAll(): List<CachedProfile>

    @Query("SELECT * FROM cached_profiles WHERE id = :id")
    suspend fun getById(id: String): CachedProfile?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(profile: CachedProfile)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(profiles: List<CachedProfile>)

    @Query("DELETE FROM cached_profiles WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM cached_profiles")
    suspend fun clearAll()
}

@Dao
interface SyncConflictDao {
    @Query("SELECT * FROM sync_conflicts WHERE resolvedAt IS NULL ORDER BY detectedAt DESC")
    suspend fun getUnresolved(): List<SyncConflict>

    @Query("SELECT * FROM sync_conflicts WHERE resolvedAt IS NULL ORDER BY detectedAt DESC")
    fun observeUnresolved(): Flow<List<SyncConflict>>

    @Query("SELECT COUNT(*) FROM sync_conflicts WHERE resolvedAt IS NULL")
    fun observeUnresolvedCount(): Flow<Int>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(conflict: SyncConflict)

    @Query("UPDATE sync_conflicts SET resolvedAt = :resolvedAt, resolution = :resolution WHERE id = :id")
    suspend fun resolve(id: String, resolvedAt: Long, resolution: String)

    @Query("DELETE FROM sync_conflicts WHERE resolvedAt IS NOT NULL AND resolvedAt < :cutoff")
    suspend fun deleteResolvedOlderThan(cutoff: Long)

    @Query("DELETE FROM sync_conflicts")
    suspend fun clearAll()
}

// ============================================================================
// Type Converters
// ============================================================================

class SyncConverters {
    private val json = Json { ignoreUnknownKeys = true }

    @TypeConverter
    fun fromOperationType(type: OperationType): String = type.name

    @TypeConverter
    fun toOperationType(value: String): OperationType = OperationType.valueOf(value)
}

// ============================================================================
// Helper Extensions
// ============================================================================

/**
 * Generate idempotency key for pending operations.
 */
fun generateIdempotencyKey(
    type: OperationType,
    table: String,
    recordId: String?
): String {
    val timestamp = System.currentTimeMillis()
    return "$type:$table:${recordId ?: "new"}:$timestamp"
}
