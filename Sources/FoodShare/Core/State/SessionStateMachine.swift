//
//  SessionStateMachine.swift
//  FoodShare
//
//  Formal state machine for authentication state management
//  Prevents impossible state transitions and ensures consistent auth state
//

#if !SKIP
import Combine
import Foundation
import OSLog
import Supabase

// MARK: - Session State

/// Represents all possible authentication states
public enum SessionState: Sendable, Equatable, CustomStringConvertible {
    /// Initial state - checking for existing session
    case initializing

    /// User is not authenticated
    case unauthenticated

    /// Authentication is in progress
    case authenticating(method: AuthMethod)

    /// User is authenticated with a valid session
    case authenticated(session: AuthenticatedSession)

    /// Refreshing the current session token
    case refreshing(session: AuthenticatedSession)

    /// Sign out is in progress
    case signingOut

    /// Session expired and needs re-authentication
    case sessionExpired(previousUserId: UUID?)

    /// Authentication failed
    case failed(error: AuthStateError)

    public var description: String {
        switch self {
        case .initializing: "Initializing"
        case .unauthenticated: "Unauthenticated"
        case let .authenticating(method): "Authenticating (\(method.rawValue))"
        case .authenticated: "Authenticated"
        case .refreshing: "Refreshing"
        case .signingOut: "Signing Out"
        case .sessionExpired: "Session Expired"
        case let .failed(error): "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties

    /// Whether the user is currently authenticated
    public var isAuthenticated: Bool {
        switch self {
        case .authenticated, .refreshing:
            true
        default:
            false
        }
    }

    /// Whether an auth operation is in progress
    public var isLoading: Bool {
        switch self {
        case .initializing, .authenticating, .signingOut, .refreshing:
            true
        default:
            false
        }
    }

    /// The current session if available
    public var session: AuthenticatedSession? {
        switch self {
        case let .authenticated(session), let .refreshing(session):
            session
        default:
            nil
        }
    }

    /// The current user ID if authenticated
    public var userId: UUID? {
        session?.userId
    }

    /// Whether the session can be refreshed
    public var canRefresh: Bool {
        if case .authenticated = self { return true }
        return false
    }

    /// Whether sign out is allowed from this state
    public var canSignOut: Bool {
        switch self {
        case .authenticated, .sessionExpired, .failed:
            true
        default:
            false
        }
    }
}

// MARK: - Authenticated Session

/// Represents a valid authenticated session
public struct AuthenticatedSession: Sendable, Equatable {
    public let userId: UUID
    public let email: String?
    public let name: String?
    public let avatarUrl: String?
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let createdAt: Date

    public var isExpired: Bool {
        expiresAt <= Date()
    }

    public var isNearExpiry: Bool {
        // Within 5 minutes of expiry
        expiresAt.timeIntervalSinceNow < 300
    }

    public var expiresIn: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }

    /// Create from Supabase Session
    public init(from session: Session) {
        userId = session.user.id
        email = session.user.email
        name = session.user.userMetadata["name"]?.value as? String
        avatarUrl = session.user.userMetadata["avatar_url"]?.value as? String
        accessToken = session.accessToken
        refreshToken = session.refreshToken
        expiresAt = Date(timeIntervalSince1970: session.expiresAt)
        createdAt = Date()
    }

    /// Create for testing
    public init(
        userId: UUID,
        email: String?,
        name: String?,
        avatarUrl: String?,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
    ) {
        self.userId = userId
        self.email = email
        self.name = name
        self.avatarUrl = avatarUrl
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        createdAt = Date()
    }
}

// MARK: - Auth State Error

/// Errors that can occur during authentication
public enum AuthStateError: LocalizedError, Sendable, Equatable {
    case invalidCredentials
    case emailNotVerified
    case userNotFound
    case networkError(String)
    case tokenRefreshFailed
    case sessionExpired
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid email or password"
        case .emailNotVerified:
            "Please verify your email address"
        case .userNotFound:
            "User not found"
        case let .networkError(message):
            "Network error: \(message)"
        case .tokenRefreshFailed:
            "Failed to refresh session"
        case .sessionExpired:
            "Your session has expired"
        case let .unknown(message):
            message
        }
    }
}

// MARK: - Session Events

/// Events that can trigger state transitions
public enum SessionEvent: Sendable {
    case initialize
    case startAuth(method: AuthMethod)
    case authSuccess(session: Session)
    case authFailure(error: AuthStateError)
    case sessionRestored(session: Session)
    case sessionNotFound
    case startRefresh
    case refreshSuccess(session: Session)
    case refreshFailure
    case startSignOut
    case signOutComplete
    case sessionExpired
    case reset
}

// MARK: - Session State Machine

/// Thread-safe state machine for authentication
@MainActor
@Observable
public final class SessionStateMachine {
    /// Shared instance
    public static let shared = SessionStateMachine()

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "SessionStateMachine")

    /// Current state
    public private(set) var state: SessionState = .initializing

    /// Publisher for state changes
    private let stateSubject = PassthroughSubject<SessionState, Never>()
    public var statePublisher: AnyPublisher<SessionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    /// State change callback
    public var onStateChange: ((SessionState, SessionState) -> Void)?

    private init() {}

    // MARK: - Event Processing

    /// Process a session event and transition to the appropriate state
    public func send(_ event: SessionEvent) {
        let previousState = state
        let nextState = nextState(for: event)

        if nextState != previousState {
            logger
                .info(
                    "Session state: \(previousState.description) → \(nextState.description) [event: \(String(describing: event))]",
                )
            state = nextState
            stateSubject.send(nextState)
            onStateChange?(previousState, nextState)
        }
    }

    /// Calculate the next state based on current state and event
    private func nextState(for event: SessionEvent) -> SessionState {
        switch (state, event) {
        // From initializing
        case (.initializing, .sessionRestored(let session)):
            return SessionState.authenticated(session: AuthenticatedSession(from: session))

        case (.initializing, .sessionNotFound):
            return SessionState.unauthenticated

        case (.initializing, .authFailure(let error)):
            return SessionState.failed(error: error)

        // From unauthenticated
        case (.unauthenticated, .startAuth(let method)):
            return SessionState.authenticating(method: method)

        case (.unauthenticated, .sessionRestored(let session)):
            return SessionState.authenticated(session: AuthenticatedSession(from: session))

        // From authenticating
        case (.authenticating, .authSuccess(let session)):
            return SessionState.authenticated(session: AuthenticatedSession(from: session))

        case (.authenticating, .authFailure(let error)):
            return SessionState.failed(error: error)

        // From authenticated
        case (.authenticated(let session), .startRefresh):
            return SessionState.refreshing(session: session)

        case (.authenticated, .startSignOut):
            return SessionState.signingOut

        case (.authenticated, .sessionExpired):
            return SessionState.sessionExpired(previousUserId: state.userId)

        // From refreshing
        case (.refreshing, .refreshSuccess(let session)):
            return SessionState.authenticated(session: AuthenticatedSession(from: session))

        case (.refreshing(let oldSession), .refreshFailure):
            return SessionState.sessionExpired(previousUserId: oldSession.userId)

        // From signing out
        case (.signingOut, .signOutComplete):
            return SessionState.unauthenticated

        // From session expired
        case (.sessionExpired, .startAuth(let method)):
            return SessionState.authenticating(method: method)

        case (.sessionExpired, .signOutComplete):
            return SessionState.unauthenticated

        // From failed
        case (.failed, .startAuth(let method)):
            return SessionState.authenticating(method: method)

        case (.failed, .reset):
            return SessionState.unauthenticated

        // Reset from any state
        case (_, .reset):
            return SessionState.unauthenticated

        // Invalid transitions - stay in current state
        default:
            logger.warning("Invalid transition attempt: \(self.state.description) + \(String(describing: event))")
            return state
        }
    }

    // MARK: - Convenience Methods

    /// Check if transition to a state is valid
    public func canTransition(to targetState: SessionState) -> Bool {
        // This is a simplified check - the full validation happens in nextState
        switch (state, targetState) {
        case (.initializing, .authenticated), (.initializing, .unauthenticated):
            true
        case (.unauthenticated, .authenticating):
            true
        case (.authenticating, .authenticated), (.authenticating, .failed):
            true
        case (.authenticated, .refreshing), (.authenticated, .signingOut), (.authenticated, .sessionExpired):
            true
        case (.refreshing, .authenticated), (.refreshing, .sessionExpired):
            true
        case (.signingOut, .unauthenticated):
            true
        case (.failed, .authenticating), (.failed, .unauthenticated):
            true
        case (.sessionExpired, .authenticating), (.sessionExpired, .unauthenticated):
            true
        default:
            false
        }
    }

    /// Reset to initial state (for testing or error recovery)
    public func reset() {
        send(.reset)
    }
}

// MARK: - Session Monitoring

extension SessionStateMachine {
    /// Start monitoring session expiry
    public func startExpiryMonitoring() {
        Task {
            while true {
                try? await Task.sleep(for: .seconds(60)) // Check every minute

                if case let .authenticated(session) = state {
                    if session.isExpired {
                        send(.sessionExpired)
                    } else if session.isNearExpiry {
                        send(.startRefresh)
                    }
                }
            }
        }
    }
}

// MARK: - Debug Support

#if DEBUG
    extension SessionStateMachine {
        /// Force a specific state (for testing only)
        public func forceState(_ newState: SessionState) {
            let previous = state
            state = newState
            stateSubject.send(newState)
            onStateChange?(previous, newState)
        }

        /// Create a mock authenticated state
        public static func mockAuthenticated() -> SessionStateMachine {
            let machine = SessionStateMachine()
            let mockSession = AuthenticatedSession(
                userId: UUID(),
                email: "test@example.com",
                name: "Test User",
                avatarUrl: nil,
                accessToken: "mock-token",
                refreshToken: "mock-refresh",
                expiresAt: Date().addingTimeInterval(3600),
            )
            machine.forceState(.authenticated(session: mockSession))
            return machine
        }
    }
#endif

#endif
