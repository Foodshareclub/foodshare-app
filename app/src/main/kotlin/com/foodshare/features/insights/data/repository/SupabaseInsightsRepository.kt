package com.foodshare.features.insights.data.repository

import io.github.jan.supabase.SupabaseClient
import com.foodshare.features.insights.domain.model.UserInsights
import com.foodshare.features.insights.domain.repository.InsightsRepository
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseInsightsRepository @Inject constructor(
    private val supabaseClient: SupabaseClient
) : InsightsRepository {

    override suspend fun getUserInsights(userId: String): Result<UserInsights> {
        return try {
            val params = buildJsonObject {
                put("p_user_id", userId)
            }

            val insights = supabaseClient.postgrest
                .rpc("get_user_insights", params)
                .decodeSingle<UserInsights>()

            Result.success(insights)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
