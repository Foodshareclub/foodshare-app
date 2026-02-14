//
//  StoreKitService.swift
//  Foodshare
//
//  Production-grade StoreKit 2 service for managing auto-renewable subscriptions
//  with robust backend sync, retry logic, caching, and offline support.
//

import Foundation
#if !SKIP
import Network
#endif
import Observation
import OSLog
#if !SKIP
import StoreKit
#endif
import Supabase
#if !SKIP
import UIKit
#endif

// MARK: - Store Error Types

enum StoreError: LocalizedError, Equatable {
    case productNotFound
    case purchaseFailed(String)
    case verificationFailed
    case userCancelled
    case networkError(String)
    case syncFailed(String)
    case backendUnavailable
    case rateLimited
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            "Subscription products not available"
        case let .purchaseFailed(message):
            "Purchase failed: \(message)"
        case .verificationFailed:
            "Could not verify your purchase"
        case .userCancelled:
            "Purchase was cancelled"
        case let .networkError(message):
            "Network error: \(message)"
        case let .syncFailed(message):
            "Failed to sync subscription: \(message)"
        case .backendUnavailable:
            "Server temporarily unavailable"
        case .rateLimited:
            "Too many requests, please wait"
        case let .unknown(message):
            message
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .backendUnavailable, .rateLimited:
            true
        default:
            false
        }
    }
}

// MARK: - Backend Response Types

/// Response from sync-subscription endpoint
struct SyncSubscriptionResponse: Codable {
    let subscriptionId: String?
    let synced: Bool
    let subscription: SubscriptionDetails?

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
        case synced
        case subscription
    }
}

/// Response from subscription status endpoint
struct PremiumCheckResponse: Codable {
    let isPremium: Bool
    let subscription: SubscriptionDetails?

    enum CodingKeys: String, CodingKey {
        case isPremium = "is_premium"
        case subscription
    }
}

/// Subscription details from backend
struct SubscriptionDetails: Codable, Equatable {
    let subscriptionId: String?
    let platform: String?
    let productId: String?
    let status: String?
    let expiresDate: String?
    let autoRenewStatus: Bool?
    let isActive: Bool?
    let environment: String?

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
        case platform
        case productId = "product_id"
        case status
        case expiresDate = "expires_date"
        case autoRenewStatus = "auto_renew_status"
        case isActive = "is_active"
        case environment
    }

    var isPremium: Bool {
        isActive == true || status == "active" || status == "in_grace_period"
    }

    var expirationDate: Date? {
        guard let dateString = expiresDate else { return nil }
        return ISO8601DateFormatter().date(from: dateString)
    }
}

// MARK: - Subscription State

/// Combined subscription state from StoreKit and backend
struct SubscriptionState: Equatable {
    var storeKitIsPremium = false
    var backendIsPremium: Bool?
    var backendSubscription: SubscriptionDetails?
    var lastSyncedAt: Date?
    var syncError: String?

    /// Authoritative premium status (backend takes precedence when available)
    var isPremium: Bool {
        backendIsPremium ?? storeKitIsPremium
    }

    /// Whether subscription data needs refresh
    var needsRefresh: Bool {
        guard let lastSync = lastSyncedAt else { return true }
        return Date().timeIntervalSince(lastSync) > 300 // 5 minutes
    }
}

// MARK: - Pending Sync Queue

/// Represents a pending sync operation for offline support
private struct PendingSyncOperation: Codable {
    let originalTransactionId: String
    let transactionId: String
    let productId: String
    let bundleId: String
    let purchaseDate: Int
    let originalPurchaseDate: Int
    let expiresDate: Int?
    let environment: String
    let userId: String
    let createdAt: Date
    let retryCount: Int

    var canRetry: Bool {
        retryCount < 5
    }
}

// MARK: - StoreKit Service

@MainActor
@Observable
final class StoreKitService {
    // MARK: - Singleton

    static let shared = StoreKitService()

    // MARK: - Observable State

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var subscriptionState = SubscriptionState()
    var isLoading = false
    var isSyncing = false
    var error: StoreError?

    // MARK: - Computed Properties

    /// Combined premium status from StoreKit and backend
    var isPremium: Bool {
        subscriptionState.isPremium
    }

    /// StoreKit-only premium status (use for immediate UI updates)
    var isPremiumLocal: Bool {
        !purchasedProductIDs.isEmpty
    }

    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == ProductID.yearly }
    }

    var currentSubscriptionProduct: Product? {
        products.first { purchasedProductIDs.contains($0.id) }
    }

    // MARK: - Product IDs

    private enum ProductID {
        static let monthly = "foodshare_1_month_subscriptions"
        static let yearly = "foodshare_1_year_subscriptions"
        static let all = [monthly, yearly]
    }

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "StoreKitService")
    private var transactionListener: Task<Void, Error>?
    nonisolated(unsafe) private var backgroundRefreshTask: Task<Void, Never>?
    nonisolated(unsafe) private var networkMonitor: NWPathMonitor?
    private var isNetworkAvailable = true

    // Cache
    private var subscriptionCache: SubscriptionDetails?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // Pending sync queue (for offline support)
    private var pendingSyncQueue: [PendingSyncOperation] = []
    private let pendingSyncKey = "com.foodshare.pendingSyncQueue"

    // Retry configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0

    // MARK: - Initialization

    private init() {
        logger.info("════════════════════════════════════════════════════════════")
        logger.info("[STORE] ▶️ INIT: StoreKitService starting initialization")
        logger.info("[STORE] 📱 Device model: \(UIDevice.current.model)")
        logger.info("[STORE] 📱 System version: \(UIDevice.current.systemVersion)")
        logger.info("[STORE] 📱 Device idiom: \(self.isIPad ? "iPad" : "iPhone")")

        setupNetworkMonitoring()
        loadPendingSyncQueue()

        Task { @MainActor in
            logger.info("[STORE] 🎧 Setting up transaction listener...")
            transactionListener = listenForTransactions()
            logger.info("[STORE] ✅ Transaction listener active")

            // iPad needs longer delay for StoreKit initialization during App Store review
            let delaySeconds = isIPad ? Self.iPadInitDelaySeconds : Self.iPhoneInitDelaySeconds
            logger
                .info(
                    "[STORE] ⏳ Starting init delay: \(delaySeconds)s (iPad=\(Self.iPadInitDelaySeconds)s, iPhone=\(Self.iPhoneInitDelaySeconds)s)",
                )
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * Double(Self.nanosPerSecond)))

            logger.info("[STORE] 📦 Starting product load...")
            await loadProducts()
            logger.info("[STORE] 📦 Product load completed, count: \(self.products.count)")

            logger.info("[STORE] 🔍 Checking subscription status...")
            await checkSubscriptionStatus()

            // Start background refresh
            startBackgroundRefresh()

            // Process any pending syncs
            await processPendingSyncQueue()

            logger
                .info(
                    "[STORE] ✅ INIT COMPLETE: isPremium=\(self.isPremium), isPremiumLocal=\(self.isPremiumLocal), products=\(self.products.count)",
                )
            logger.info("════════════════════════════════════════════════════════════")
        }
    }

    deinit {
        networkMonitor?.cancel()
        backgroundRefreshTask?.cancel()
    }

    // MARK: - Retry Configuration

    private static let maxRetryAttempts = 5
    private static let baseRetryDelay: UInt64 = 2_000_000_000
    private static let nanosPerSecond: UInt64 = 1_000_000_000
    private static let iPadInitDelaySeconds: TimeInterval = 1.5
    private static let iPhoneInitDelaySeconds: TimeInterval = 0.5
    private static let productLoadTimeout: TimeInterval = 45
    private static let canMakePaymentsTimeout: TimeInterval = 5
    private static let environmentDetectionTimeout: TimeInterval = 3

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasAvailable = self?.isNetworkAvailable ?? false
                self?.isNetworkAvailable = path.status == .satisfied

                if !wasAvailable, path.status == .satisfied {
                    self?.logger.info("[STORE] 🌐 Network restored, processing pending syncs...")
                    await self?.processPendingSyncQueue()
                }
            }
        }
        networkMonitor?.start(queue: DispatchQueue(label: "com.foodshare.networkMonitor"))
    }

    // MARK: - Background Refresh

    private func startBackgroundRefresh() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300 * Self.nanosPerSecond) // 5 minutes
                await self?.refreshSubscriptionStateIfNeeded()
            }
        }
    }

    private func refreshSubscriptionStateIfNeeded() async {
        guard subscriptionState.needsRefresh else { return }
        guard isNetworkAvailable else {
            logger.debug("[STORE] Skipping refresh - network unavailable")
            return
        }

        logger.debug("[STORE] 🔄 Background refresh triggered")
        _ = await checkSubscriptionFromBackend()
    }

    // MARK: - Pending Sync Queue

    private func loadPendingSyncQueue() {
        if let data = UserDefaults.standard.data(forKey: pendingSyncKey),
           let queue = try? JSONDecoder().decode([PendingSyncOperation].self, from: data)
        {
            pendingSyncQueue = queue
            logger.info("[STORE] Loaded \(queue.count) pending sync operations")
        }
    }

    private func savePendingSyncQueue() {
        if let data = try? JSONEncoder().encode(pendingSyncQueue) {
            UserDefaults.standard.set(data, forKey: pendingSyncKey)
        }
    }

    private func addToPendingSyncQueue(_ operation: PendingSyncOperation) {
        pendingSyncQueue.append(operation)
        savePendingSyncQueue()
        logger.info("[STORE] Added transaction to pending sync queue: \(operation.originalTransactionId)")
    }

    private func removeFromPendingSyncQueue(_ transactionId: String) {
        pendingSyncQueue.removeAll { $0.originalTransactionId == transactionId }
        savePendingSyncQueue()
    }

    private func processPendingSyncQueue() async {
        guard isNetworkAvailable else { return }
        guard !pendingSyncQueue.isEmpty else { return }

        let count = pendingSyncQueue.count
        logger.info("[STORE] Processing \(count) pending sync operations...")

        let operations = pendingSyncQueue
        for operation in operations {
            guard operation.canRetry else {
                logger
                    .warning(
                        "[STORE] Removing failed sync operation after max retries: \(operation.originalTransactionId)",
                    )
                removeFromPendingSyncQueue(operation.originalTransactionId)
                continue
            }

            do {
                try await syncOperationWithBackend(operation)
                removeFromPendingSyncQueue(operation.originalTransactionId)
                logger.info("[STORE] ✅ Successfully synced pending operation: \(operation.originalTransactionId)")
            } catch {
                logger.warning("[STORE] Failed to sync pending operation: \(error.localizedDescription)")
                // Update retry count
                if let index = pendingSyncQueue
                    .firstIndex(where: { $0.originalTransactionId == operation.originalTransactionId })
                {
                    let updated = PendingSyncOperation(
                        originalTransactionId: operation.originalTransactionId,
                        transactionId: operation.transactionId,
                        productId: operation.productId,
                        bundleId: operation.bundleId,
                        purchaseDate: operation.purchaseDate,
                        originalPurchaseDate: operation.originalPurchaseDate,
                        expiresDate: operation.expiresDate,
                        environment: operation.environment,
                        userId: operation.userId,
                        createdAt: operation.createdAt,
                        retryCount: operation.retryCount + 1,
                    )
                    pendingSyncQueue[index] = updated
                    savePendingSyncQueue()
                }
            }
        }
    }

    // MARK: - Load Products

    private var loadingTask: Task<Void, Never>?

    func loadProducts() async {
        logger.info("[STORE] ▶️ loadProducts() called")

        guard products.isEmpty else {
            logger.info("[STORE] ⏭️ Products already loaded (\(self.products.count) products), skipping")
            return
        }

        if let existingTask = loadingTask {
            logger.info("[STORE] ⏳ Load already in progress, waiting for existing task...")
            await existingTask.value
            return
        }

        let task = Task { @MainActor in
            await forceLoadProducts()
        }
        loadingTask = task
        await task.value
        loadingTask = nil
    }

    func forceLoadProducts() async {
        logger.info("────────────────────────────────────────────────────────────")
        logger.info("[STORE] ▶️ forceLoadProducts() STARTING")
        products = []
        isLoading = true
        error = nil

        let canMakePayments = await checkCanMakePaymentsWithTimeout()
        guard canMakePayments else {
            error = .unknown("In-app purchases are restricted on this device")
            isLoading = false
            return
        }

        for attempt in 1 ... Self.maxRetryAttempts {
            do {
                let storeProducts = try await fetchProductsWithTimeout()

                if storeProducts.isEmpty {
                    if attempt < Self.maxRetryAttempts {
                        let delay = Self.baseRetryDelay << (attempt - 1)
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    error = .productNotFound
                } else {
                    products = storeProducts.sorted { $0.price < $1.price }
                    error = nil
                    break
                }
            } catch {
                if attempt == Self.maxRetryAttempts {
                    self.error = .networkError(error.localizedDescription)
                } else {
                    let delay = Self.baseRetryDelay << (attempt - 1)
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        isLoading = false
        logger.info("[STORE] ✅ forceLoadProducts() completed, products: \(self.products.count)")
    }

    private func checkCanMakePaymentsWithTimeout() async -> Bool {
        let timeoutNanos = UInt64(Self.canMakePaymentsTimeout * Double(Self.nanosPerSecond))

        return await withTaskGroup(of: Bool?.self) { group in
            group.addTask {
                await AppStore.canMakePayments
            }

            group.addTask { [timeoutNanos] in
                try? await Task.sleep(nanoseconds: timeoutNanos)
                return nil
            }

            if let result = await group.next(), let canMake = result {
                group.cancelAll()
                return canMake
            }

            group.cancelAll()
            return true
        }
    }

    private func fetchProductsWithTimeout() async throws -> [Product] {
        let timeoutNanos = UInt64(Self.productLoadTimeout * Double(Self.nanosPerSecond))

        return try await withThrowingTaskGroup(of: [Product].self) { group in
            group.addTask {
                try await Product.products(for: ProductID.all)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanos)
                throw StoreError.networkError("Request timed out")
            }

            guard let result = try await group.next() else {
                throw StoreError.networkError("Request timed out")
            }

            group.cancelAll()
            return result
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction {
        logger.info("[STORE] Starting purchase for: \(product.id)")
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            // Set appAccountToken for user linking
            let options = Product.PurchaseOption.appAccountToken(appAccountToken)

            let result = try await product.purchase(options: Set([options]))

            switch result {
            case let .success(verification):
                let transaction = try Self.checkVerified(verification)

                // Optimistic update - show premium immediately
                purchasedProductIDs.insert(product.id)
                subscriptionState.storeKitIsPremium = true

                await transaction.finish()
                logger.info("[STORE] ✅ Purchase successful: \(product.id)")
                HapticManager.success()

                // Sync with backend (with retry)
                await syncSubscriptionWithBackend(transaction)

                return transaction

            case .userCancelled:
                throw StoreError.userCancelled

            case .pending:
                throw StoreError.unknown("Purchase is pending approval")

            @unknown default:
                throw StoreError.unknown("Unknown purchase result")
            }
        } catch StoreError.userCancelled {
            throw StoreError.userCancelled
        } catch StoreError.verificationFailed {
            error = .verificationFailed
            HapticManager.error()
            throw StoreError.verificationFailed
        } catch {
            let storeError = StoreError.purchaseFailed(error.localizedDescription)
            self.error = storeError
            HapticManager.error()
            throw storeError
        }
    }

    /// Generates a deterministic app account token from user ID
    private var appAccountToken: UUID {
        guard let userId = AuthenticationService.shared.currentUser?.id else {
            return UUID()
        }
        return userId
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        logger.info("[STORE] Restoring purchases")
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()

            // Sync all current entitlements with backend
            for await result in Transaction.currentEntitlements {
                if case let .verified(transaction) = result {
                    await syncSubscriptionWithBackend(transaction)
                }
            }

            logger.info("[STORE] Purchases restored successfully")
            HapticManager.success()
        } catch {
            logger.error("[STORE] Failed to restore purchases: \(error.localizedDescription)")
            self.error = .networkError(error.localizedDescription)
            HapticManager.error()
        }
    }

    // MARK: - Check Subscription Status

    func checkSubscriptionStatus() async {
        logger.info("[STORE] 🔍 checkSubscriptionStatus() starting...")

        var validSubscriptions: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)

                if transaction.productType == .autoRenewable {
                    if transaction.revocationDate == nil {
                        validSubscriptions.insert(transaction.productID)
                    }
                }
            } catch {
                logger.warning("[STORE] ⚠️ Failed to verify transaction: \(error.localizedDescription)")
            }
        }

        purchasedProductIDs = validSubscriptions
        subscriptionState.storeKitIsPremium = !validSubscriptions.isEmpty

        logger
            .info(
                "[STORE] 🔍 StoreKit status: isPremiumLocal=\(self.isPremiumLocal), subscriptions=\(validSubscriptions.count)",
            )

        // Also check backend status
        _ = await checkSubscriptionFromBackend()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await transaction.finish()
                    await self?.checkSubscriptionStatus()
                    await self?.syncSubscriptionWithBackend(transaction)
                } catch {
                    self?.logger.error("[STORE] Transaction listener error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Verification

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case let .verified(safe):
            return safe
        }
    }

    // MARK: - Helpers

    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    func subscriptionPeriod(for product: Product) -> String {
        guard let subscription = product.subscription else { return "" }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        switch unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return ""
        }
    }

    func retryLoadProductsIfNeeded() async {
        guard products.isEmpty, !isLoading, error != nil else { return }
        error = nil
        await loadProducts()
    }

    // MARK: - Backend Sync

    private var supabase: SupabaseClient {
        AuthenticationService.shared.supabase
    }

    /// Syncs a transaction with the backend using retry logic
    func syncSubscriptionWithBackend(_ transaction: Transaction) async {
        guard let userId = AuthenticationService.shared.currentUser?.id else {
            logger.warning("[STORE] Cannot sync - user not authenticated")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        logger.info("[STORE] 🔄 Syncing subscription with backend...")
        logger.info("[STORE]    originalTransactionId: \(transaction.originalID)")
        logger.info("[STORE]    productId: \(transaction.productID)")

        let environment = mapTransactionEnvironment(transaction.environment)
        let bundleId = Bundle.main.bundleIdentifier ?? "com.flutterflow.foodshare"

        let operation = PendingSyncOperation(
            originalTransactionId: String(transaction.originalID),
            transactionId: String(transaction.id),
            productId: transaction.productID,
            bundleId: bundleId,
            purchaseDate: Int(transaction.purchaseDate.timeIntervalSince1970 * 1000),
            originalPurchaseDate: Int(transaction.originalPurchaseDate.timeIntervalSince1970 * 1000),
            expiresDate: transaction.expirationDate.map { Int($0.timeIntervalSince1970 * 1000) },
            environment: environment,
            userId: userId.uuidString,
            createdAt: Date(),
            retryCount: 0,
        )

        // If offline, queue for later
        guard isNetworkAvailable else {
            logger.info("[STORE] 📴 Offline - queuing sync for later")
            addToPendingSyncQueue(operation)
            return
        }

        do {
            try await syncOperationWithBackend(operation)
            logger.info("[STORE] ✅ Subscription synced successfully")
            subscriptionState.syncError = nil
        } catch {
            logger.error("[STORE] ❌ Sync failed, queuing for retry: \(error.localizedDescription)")
            addToPendingSyncQueue(operation)
            subscriptionState.syncError = error.localizedDescription
        }
    }

    private func syncOperationWithBackend(_ operation: PendingSyncOperation) async throws {
        try await retryWithBackoff(maxAttempts: maxRetryAttempts) { [weak self] in
            guard let self else { return }

            let body: [String: AnyJSON] = try [
                "platform": AnyJSON("apple"),
                "originalTransactionId": AnyJSON(operation.originalTransactionId),
                "transactionId": AnyJSON(operation.transactionId),
                "productId": AnyJSON(operation.productId),
                "bundleId": AnyJSON(operation.bundleId),
                "purchaseDate": AnyJSON(operation.purchaseDate),
                "originalPurchaseDate": AnyJSON(operation.originalPurchaseDate),
                "expiresDate": AnyJSON(operation.expiresDate as Any),
                "environment": AnyJSON(operation.environment),
                "appAccountToken": AnyJSON(operation.userId),
                "status": AnyJSON("active"),
                "autoRenewStatus": AnyJSON(true),
            ]

            let _: SyncSubscriptionResponse = try await SubscriptionAPIService.shared.verifyReceipt(
                receiptData: receiptData
            )
        }
    }

    /// Checks subscription status from backend with caching
    func checkSubscriptionFromBackend() async -> SubscriptionDetails? {
        guard AuthenticationService.shared.currentUser?.id != nil else {
            logger.debug("[STORE] Cannot check backend - user not authenticated")
            return nil
        }

        // Check cache first
        if let cached = subscriptionCache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration
        {
            logger.debug("[STORE] Using cached subscription data")
            return cached
        }

        guard isNetworkAvailable else {
            logger.debug("[STORE] Cannot check backend - offline")
            return subscriptionCache
        }

        logger.debug("[STORE] 🔍 Checking subscription from backend...")

        do {
            let response: PremiumCheckResponse = try await retryWithBackoff(maxAttempts: 2) {
                try await self.supabase.functions.invoke(
                    "sync-subscription",
                    options: FunctionInvokeOptions(method: .get),
                )
            }

            // Update cache
            subscriptionCache = response.subscription
            cacheTimestamp = Date()

            // Update state
            subscriptionState.backendIsPremium = response.isPremium
            subscriptionState.backendSubscription = response.subscription
            subscriptionState.lastSyncedAt = Date()
            subscriptionState.syncError = nil

            logger.info("[STORE] ✅ Backend check complete: isPremium=\(response.isPremium)")

            return response.subscription
        } catch {
            logger.error("[STORE] ❌ Backend check failed: \(error.localizedDescription)")
            subscriptionState.syncError = error.localizedDescription
            return subscriptionCache
        }
    }

    /// Authoritative premium check from backend (with fallback to StoreKit)
    func isPremiumFromBackend() async -> Bool {
        guard let userId = AuthenticationService.shared.currentUser?.id else {
            return isPremiumLocal
        }

        // Quick return from cache if valid
        if let cached = subscriptionState.backendIsPremium,
           !subscriptionState.needsRefresh
        {
            return cached
        }

        guard isNetworkAvailable else {
            return isPremiumLocal
        }

        do {
            let result: Bool = try await retryWithBackoff(maxAttempts: 2) {
                try await self.supabase.rpc(
                    "billing_is_user_premium",
                    params: ["p_user_id": AnyJSON(userId.uuidString)],
                ).execute().value
            }

            subscriptionState.backendIsPremium = result
            subscriptionState.lastSyncedAt = Date()
            return result
        } catch {
            logger.error("[STORE] ❌ Backend premium check failed: \(error.localizedDescription)")
            return isPremiumLocal
        }
    }

    /// Invalidates cache and forces a fresh backend check
    func refreshSubscriptionStatus() async {
        subscriptionCache = nil
        cacheTimestamp = nil
        await checkSubscriptionStatus()
    }

    // MARK: - Retry Helper

    private func retryWithBackoff<T>(
        maxAttempts: Int,
        operation: @escaping () async throws -> T,
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1 ... maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                logger.warning("[STORE] Attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)")

                if attempt < maxAttempts {
                    let delay = min(baseRetryDelay * pow(2.0, Double(attempt - 1)), maxRetryDelay)
                    let jitter = Double.random(in: 0 ..< delay * 0.1)
                    try? await Task.sleep(nanoseconds: UInt64((delay + jitter) * 1_000_000_000))
                }
            }
        }

        throw lastError ?? StoreError.unknown("Unknown error")
    }

    private func mapTransactionEnvironment(_ env: AppStore.Environment) -> String {
        if env == .sandbox || env == .xcode {
            "Sandbox"
        } else {
            "Production"
        }
    }
}
