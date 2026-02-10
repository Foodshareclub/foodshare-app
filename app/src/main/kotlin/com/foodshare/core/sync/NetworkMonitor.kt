package com.foodshare.core.sync

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Network connectivity state.
 */
enum class NetworkStatus {
    /** Device is online with good connection */
    AVAILABLE,
    /** Device is online but connection may be limited */
    LIMITED,
    /** Device is offline */
    UNAVAILABLE,
    /** Network status is being determined */
    UNKNOWN
}

/**
 * Detailed network information.
 */
data class NetworkInfo(
    val status: NetworkStatus,
    val isWifi: Boolean,
    val isCellular: Boolean,
    val isMetered: Boolean,
    val hasInternet: Boolean,
    val downloadSpeedKbps: Int? = null,
    val uploadSpeedKbps: Int? = null
)

/**
 * Monitors network connectivity status.
 *
 * Features:
 * - Real-time connectivity changes via StateFlow
 * - Detailed network type information
 * - Callbacks for sync trigger on reconnection
 *
 * SYNC: This mirrors Swift FoodshareCore.NetworkMonitor
 */
@Singleton
class NetworkMonitor @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private const val TAG = "NetworkMonitor"
    }

    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager

    private val _isOnline = MutableStateFlow(checkInitialConnectivity())
    val isOnline: StateFlow<Boolean> = _isOnline.asStateFlow()

    private val _networkStatus = MutableStateFlow(NetworkStatus.UNKNOWN)
    val networkStatus: StateFlow<NetworkStatus> = _networkStatus.asStateFlow()

    private val _networkInfo = MutableStateFlow(getCurrentNetworkInfo())
    val networkInfo: StateFlow<NetworkInfo> = _networkInfo.asStateFlow()

    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // Listeners for reconnection events
    private val reconnectionListeners = mutableListOf<() -> Unit>()

    init {
        startMonitoring()
    }

    /**
     * Start monitoring network changes.
     */
    private fun startMonitoring() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.d(TAG, "Network available")
                val wasOffline = !_isOnline.value
                updateNetworkState(network)

                // Trigger reconnection listeners if we just came online
                if (wasOffline && _isOnline.value) {
                    notifyReconnection()
                }
            }

            override fun onLost(network: Network) {
                Log.d(TAG, "Network lost")
                _isOnline.value = false
                _networkStatus.value = NetworkStatus.UNAVAILABLE
                _networkInfo.value = NetworkInfo(
                    status = NetworkStatus.UNAVAILABLE,
                    isWifi = false,
                    isCellular = false,
                    isMetered = false,
                    hasInternet = false
                )
            }

            override fun onCapabilitiesChanged(
                network: Network,
                capabilities: NetworkCapabilities
            ) {
                Log.d(TAG, "Network capabilities changed")
                updateNetworkState(network, capabilities)
            }
        }

        try {
            connectivityManager.registerNetworkCallback(request, networkCallback!!)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register network callback", e)
        }
    }

    /**
     * Stop monitoring network changes.
     */
    fun stopMonitoring() {
        networkCallback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to unregister network callback", e)
            }
        }
        networkCallback = null
    }

    /**
     * Check initial connectivity status.
     */
    private fun checkInitialConnectivity(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    /**
     * Update network state from current network.
     */
    private fun updateNetworkState(
        network: Network,
        capabilities: NetworkCapabilities? = null
    ) {
        val caps = capabilities
            ?: connectivityManager.getNetworkCapabilities(network)
            ?: return

        val hasInternet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        val isValidated = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        val isWifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
        val isCellular = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        val isMetered = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)

        val status = when {
            hasInternet && isValidated -> NetworkStatus.AVAILABLE
            hasInternet -> NetworkStatus.LIMITED
            else -> NetworkStatus.UNAVAILABLE
        }

        _isOnline.value = status == NetworkStatus.AVAILABLE
        _networkStatus.value = status
        _networkInfo.value = NetworkInfo(
            status = status,
            isWifi = isWifi,
            isCellular = isCellular,
            isMetered = isMetered,
            hasInternet = hasInternet,
            downloadSpeedKbps = caps.linkDownstreamBandwidthKbps,
            uploadSpeedKbps = caps.linkUpstreamBandwidthKbps
        )
    }

    /**
     * Get current network info synchronously.
     */
    private fun getCurrentNetworkInfo(): NetworkInfo {
        val network = connectivityManager.activeNetwork
        if (network == null) {
            return NetworkInfo(
                status = NetworkStatus.UNAVAILABLE,
                isWifi = false,
                isCellular = false,
                isMetered = false,
                hasInternet = false
            )
        }

        val caps = connectivityManager.getNetworkCapabilities(network)
            ?: return NetworkInfo(
                status = NetworkStatus.UNAVAILABLE,
                isWifi = false,
                isCellular = false,
                isMetered = false,
                hasInternet = false
            )

        return NetworkInfo(
            status = if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED))
                NetworkStatus.AVAILABLE else NetworkStatus.LIMITED,
            isWifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI),
            isCellular = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR),
            isMetered = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED),
            hasInternet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET),
            downloadSpeedKbps = caps.linkDownstreamBandwidthKbps,
            uploadSpeedKbps = caps.linkUpstreamBandwidthKbps
        )
    }

    /**
     * Check if currently online (synchronous).
     */
    fun isCurrentlyOnline(): Boolean = _isOnline.value

    /**
     * Observe network connectivity as a Flow.
     * Note: StateFlow already provides distinct values, no need for distinctUntilChanged()
     */
    fun observeConnectivity(): Flow<Boolean> = isOnline

    /**
     * Observe detailed network status changes.
     * Note: StateFlow already provides distinct values, no need for distinctUntilChanged()
     */
    fun observeNetworkStatus(): Flow<NetworkStatus> = networkStatus

    /**
     * Add a listener for reconnection events.
     *
     * Useful for triggering sync when coming back online.
     */
    fun addReconnectionListener(listener: () -> Unit) {
        reconnectionListeners.add(listener)
    }

    /**
     * Remove a reconnection listener.
     */
    fun removeReconnectionListener(listener: () -> Unit) {
        reconnectionListeners.remove(listener)
    }

    /**
     * Notify all reconnection listeners.
     */
    private fun notifyReconnection() {
        Log.d(TAG, "Notifying ${reconnectionListeners.size} reconnection listeners")
        reconnectionListeners.forEach { listener ->
            try {
                listener()
            } catch (e: Exception) {
                Log.e(TAG, "Error in reconnection listener", e)
            }
        }
    }

    /**
     * Wait for network connectivity.
     *
     * @return true when connected, false if cancelled
     */
    suspend fun awaitConnectivity(): Boolean {
        if (_isOnline.value) return true

        return callbackFlow {
            var callback: ConnectivityManager.NetworkCallback? = null

            callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    trySend(true)
                }
            }

            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            connectivityManager.registerNetworkCallback(request, callback)

            awaitClose {
                callback?.let {
                    connectivityManager.unregisterNetworkCallback(it)
                }
            }
        }.distinctUntilChanged().let { flow ->
            var result = false
            flow.collect {
                result = it
                return@collect
            }
            result
        }
    }
}
