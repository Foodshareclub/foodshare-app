//
//  NetworkMonitor.swift
//  Foodshare
//
//  Network connectivity monitoring service
//  Posts notifications when connectivity status changes
//

import Foundation
#if !SKIP
import Network
#endif
import OSLog

// MARK: - Network Monitor

/// Monitors network connectivity and posts notifications on status changes
/// Uses actor isolation for thread-safe state management
actor NetworkMonitorActor {
    // MARK: - State

    private(set) var isConnected = true
    private(set) var connectionType: ConnectionType = .unknown
    private(set) var isExpensive = false
    private(set) var isConstrained = false

    enum ConnectionType: String, Sendable {
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case wiredEthernet = "Ethernet"
        case unknown = "Unknown"
    }

    #if !SKIP
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.flutterflow.foodshare.NetworkMonitor", qos: .utility)
    #endif
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "NetworkMonitor")
    private var isMonitoring = false

    init() {
        #if !SKIP
        monitor = NWPathMonitor()
        #endif
    }

    #if !SKIP
    deinit {
        monitor.cancel()
    }
    #endif

    // MARK: - Public Methods

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        logger.info("📡 Starting network monitoring")

        #if !SKIP
        monitor.pathUpdateHandler = { [weak monitor] path in
            guard monitor != nil else { return }
            Task {
                await NetworkMonitor.shared.actor.handlePathUpdate(path)
            }
        }

        monitor.start(queue: monitorQueue)
        #endif
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false

        logger.info("📡 Stopping network monitoring")
        #if !SKIP
        monitor.cancel()
        #endif
    }

    #if !SKIP
    // MARK: - Private Methods

    func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        let newIsConnected = path.status == .satisfied

        isConnected = newIsConnected
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = .unknown
        }

        logger.debug("📡 Network status: \(newIsConnected ? "Connected" : "Disconnected") via \(self.connectionType.rawValue)")

        if wasConnected != newIsConnected {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": newIsConnected]
                )
            }
        }
    }
    #endif
}

/// MainActor-isolated wrapper for NetworkMonitorActor
@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "NetworkMonitor")

    // MARK: - Actor

    fileprivate let actor = NetworkMonitorActor()
    
    // MARK: - Observable State
    
    private(set) var isConnected = true
    var isOffline: Bool { !isConnected }
    private(set) var connectionType: NetworkMonitorActor.ConnectionType = .unknown
    private(set) var isExpensive = false
    private(set) var isConstrained = false
    
    private init() {
        Task {
            await syncState()
            await startMonitoring()
        }
    }
    
    // MARK: - Public Methods
    
    func start() {
        Task {
            await actor.start()
            await syncState()
        }
    }
    
    func stop() {
        Task {
            await actor.stop()
        }
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() async {
        await actor.start()
        
        // Poll state periodically for UI updates
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await syncState()
            }
        }
    }
    
    private func syncState() async {
        isConnected = await actor.isConnected
        connectionType = await actor.connectionType
        isExpensive = await actor.isExpensive
        isConstrained = await actor.isConstrained
    }

    // MARK: - Convenience Methods

    /// Check if we should warn about expensive connection
    var shouldWarnAboutExpensiveConnection: Bool {
        isConnected && isExpensive && !isConstrained
    }

    /// Human-readable status description
    var statusDescription: String {
        if !isConnected {
            return "Offline"
        }
        var status = connectionType.rawValue
        if isConstrained {
            status += " (Low Data)"
        } else if isExpensive {
            status += " (Metered)"
        }
        return status
    }
}

// MARK: - Reachability Check

extension NetworkMonitor {
    /// Perform a reachability check to a specific host
    func checkReachability(to host: String) async -> Bool {
        guard isConnected else { return false }

        do {
            guard let url = URL(string: "https://\(host)") else {
                logger.warning("📡 Invalid host for reachability check: \(host)")
                return false
            }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                return (200 ... 299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            logger.debug("📡 Reachability check failed for \(host): \(error.localizedDescription)")
            return false
        }
    }

    /// Check if Supabase is reachable
    func checkSupabaseReachability() async -> Bool {
        // Use environment variable or fallback
        let supabaseHost = ProcessInfo.processInfo.environment["SUPABASE_URL"]?
            .replacingOccurrences(of: "https://", with: "")
            .components(separatedBy: "/").first ?? "api.foodshare.club"

        return await checkReachability(to: supabaseHost)
    }
}

// MARK: - Network Quality

extension NetworkMonitor {
    /// Estimated network quality based on connection properties
    enum NetworkQuality: String, Sendable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case offline = "Offline"
    }

    var estimatedQuality: NetworkQuality {
        guard isConnected else { return .offline }

        switch connectionType {
        case .wifi:
            return isConstrained ? .fair : .excellent
        case .wiredEthernet:
            return .excellent
        case .cellular:
            if isConstrained {
                return .poor
            }
            return isExpensive ? .good : .fair
        case .unknown:
            return .fair
        }
    }
}
