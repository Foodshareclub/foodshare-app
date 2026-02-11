package com.foodshare.features.fridges.data.repository

import io.github.jan.supabase.SupabaseClient
import com.foodshare.features.fridges.data.dto.CommunityFridgeDto
import com.foodshare.features.fridges.data.dto.FridgeReportDto
import com.foodshare.features.fridges.data.dto.ReportStockRequest
import com.foodshare.features.fridges.data.dto.toDomain
import com.foodshare.features.fridges.domain.model.CommunityFridge
import com.foodshare.features.fridges.domain.model.FridgeReport
import com.foodshare.features.fridges.domain.model.StockLevel
import com.foodshare.features.fridges.domain.repository.FridgeRepository
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.rpc
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseFridgeRepository @Inject constructor(
    private val supabaseClient: SupabaseClient
) : FridgeRepository {

    override fun getNearbyFridges(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ): Flow<List<CommunityFridge>> = flow {
        try {
            val params = buildJsonObject {
                put("p_latitude", latitude)
                put("p_longitude", longitude)
                put("p_radius_km", radiusKm)
            }

            val fridges = supabaseClient.postgrest
                .rpc("get_nearby_fridges", params)
                .decodeList<CommunityFridgeDto>()
                .map { it.toDomain() }

            emit(fridges)
        } catch (e: Exception) {
            emit(emptyList())
        }
    }

    override suspend fun getFridgeDetail(id: Int): Result<CommunityFridge> {
        return try {
            val fridge = supabaseClient.postgrest
                .from("community_fridges")
                .select(columns = Columns.ALL) {
                    filter {
                        eq("id", id)
                    }
                }
                .decodeSingle<CommunityFridgeDto>()

            Result.success(fridge.toDomain())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun reportStock(
        fridgeId: Int,
        stockLevel: StockLevel,
        notes: String?
    ): Result<Unit> {
        return try {
            val request = ReportStockRequest(
                fridgeId = fridgeId,
                stockLevel = when (stockLevel) {
                    StockLevel.FULL -> "full"
                    StockLevel.HALF -> "half"
                    StockLevel.LOW -> "low"
                    StockLevel.EMPTY -> "empty"
                    StockLevel.UNKNOWN -> "unknown"
                },
                notes = notes
            )

            supabaseClient.postgrest
                .from("fridge_reports")
                .insert(request)

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun getFridgeReports(fridgeId: Int): Result<List<FridgeReport>> {
        return try {
            val reports = supabaseClient.postgrest
                .from("fridge_reports")
                .select(columns = Columns.ALL) {
                    filter {
                        eq("fridge_id", fridgeId)
                    }
                    order("created_at", Order.DESCENDING)
                    limit(5)
                }
                .decodeList<FridgeReportDto>()
                .map { it.toDomain() }

            Result.success(reports)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
