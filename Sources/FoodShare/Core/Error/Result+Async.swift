//
//  Result+Async.swift
//  Foodshare
//
//  Async extensions for Result type with integrated error capture.
//  Provides elegant error handling patterns that replace try? with proper logging.
//
//  Usage:
//  ```swift
//  // Instead of: let data = try? await riskyOperation()
//  // Use:
//  let result = await ResultCapture.capture(operation: "fetchData") {
//      try await riskyOperation()
//  }
//
//  switch result {
//  case .success(let data): handleData(data)
//  case .failure(let error): handleError(error)
//  }
//  ```
//


#if !SKIP
import Foundation

#if !SKIP
// MARK: - Result Async Extensions

/// Result capture helpers for async operations
enum ResultCapture {
    /// Capture an async throwing operation into a Result
    ///
    /// This is the primary replacement for try? - it captures the error
    /// for logging/reporting instead of silently discarding it.
    static func capture<T: Sendable>(
        _ body: () async throws -> T,
    ) async -> Result<T, Error> {
        do {
            let value = try await body()
            return .success(value)
        } catch {
            return .failure(error)
        }
    }

    /// Capture with operation context for logging
    static func capture<T: Sendable>(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ body: () async throws -> T,
    ) async -> Result<T, Error> {
        do {
            let value = try await body()
            return .success(value)
        } catch {
            // Log the error with context
            await captureError(
                error,
                operation: operation,
                file: file,
                function: function,
                line: line,
            )
            return .failure(error)
        }
    }
}

// MARK: - Result Map Extensions

extension Result {
    /// Async map for success value
    public func asyncMap<NewSuccess: Sendable>(
        _ transform: @Sendable (Success) async -> NewSuccess,
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(value):
            await .success(transform(value))
        case let .failure(error):
            .failure(error)
        }
    }

    /// Async flatMap for success value
    public func asyncFlatMap<NewSuccess: Sendable>(
        _ transform: @Sendable (Success) async -> Result<NewSuccess, Failure>,
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(value):
            await transform(value)
        case let .failure(error):
            .failure(error)
        }
    }

    /// Async map for failure value
    public func asyncMapError<NewFailure: Error>(
        _ transform: @Sendable (Failure) async -> NewFailure,
    ) async -> Result<Success, NewFailure> {
        switch self {
        case let .success(value):
            .success(value)
        case let .failure(error):
            await .failure(transform(error))
        }
    }
}

// MARK: - Result Recovery Extensions

extension Result where Failure == Error {
    /// Recover from failure with a fallback value
    public func recover(
        _ fallback: @autoclosure () -> Success,
    ) -> Success {
        switch self {
        case let .success(value):
            value
        case .failure:
            fallback()
        }
    }

    /// Recover from failure with an async fallback
    public func asyncRecover(
        _ fallback: @Sendable () async -> Success,
    ) async -> Success {
        switch self {
        case let .success(value):
            value
        case .failure:
            await fallback()
        }
    }

    /// Recover from failure with another Result
    public func asyncRecoverCatching(
        _ fallback: @Sendable () async throws -> Success,
    ) async -> Result<Success, Error> where Success: Sendable {
        switch self {
        case let .success(value):
            .success(value)
        case .failure:
            await ResultCapture.capture(fallback)
        }
    }

    /// Execute side effect on failure
    public func onFailure(
        _ handler: @Sendable (Error) async -> Void,
    ) async -> Result<Success, Failure> {
        if case let .failure(error) = self {
            await handler(error)
        }
        return self
    }

    /// Execute side effect on success
    public func onSuccess(
        _ handler: @Sendable (Success) async -> Void,
    ) async -> Result<Success, Failure> {
        if case let .success(value) = self {
            await handler(value)
        }
        return self
    }
}

// MARK: - Result Logging Extensions

extension Result where Failure == Error, Success: Sendable {
    /// Log the result and return the value or nil
    public func loggedOrNil(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async -> Success? {
        switch self {
        case let .success(value):
            return value
        case let .failure(error):
            await captureError(
                error,
                operation: operation,
                file: file,
                function: function,
                line: line,
            )
            return nil
        }
    }

    /// Log failure and rethrow
    public func loggedOrThrow(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
    ) async throws -> Success {
        switch self {
        case let .success(value):
            return value
        case let .failure(error):
            await captureError(
                error,
                operation: operation,
                file: file,
                function: function,
                line: line,
            )
            throw error
        }
    }
}

// MARK: - Async Result Combiner

/// Combine multiple async results
public enum AsyncResultCombiner {
    /// Combine two results
    public static func combine<A: Sendable, B: Sendable>(
        _ a: @escaping @Sendable () async throws -> A,
        _ b: @escaping @Sendable () async throws -> B,
    ) async -> Result<(A, B), Error> {
        await ResultCapture.capture {
            async let resultA = a()
            async let resultB = b()
            return try await (resultA, resultB)
        }
    }

    /// Combine three results
    public static func combine<A: Sendable, B: Sendable, C: Sendable>(
        _ a: @escaping @Sendable () async throws -> A,
        _ b: @escaping @Sendable () async throws -> B,
        _ c: @escaping @Sendable () async throws -> C,
    ) async -> Result<(A, B, C), Error> {
        await ResultCapture.capture {
            async let resultA = a()
            async let resultB = b()
            async let resultC = c()
            return try await (resultA, resultB, resultC)
        }
    }

    /// Combine an array of homogeneous async operations
    public static func all<T: Sendable>(
        _ operations: [@Sendable () async throws -> T],
    ) async -> Result<[T], Error> {
        await ResultCapture.capture {
            try await withThrowingTaskGroup(of: T.self) { group in
                for operation in operations {
                    group.addTask { try await operation() }
                }

                var results: [T] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        }
    }

    /// Execute operations in sequence, stopping on first failure
    public static func sequence<T: Sendable>(
        _ operations: [@Sendable () async throws -> T],
    ) async -> Result<[T], Error> {
        await ResultCapture.capture {
            var results: [T] = []
            for operation in operations {
                let result = try await operation()
                results.append(result)
            }
            return results
        }
    }

    /// Execute operations, collecting both successes and failures
    public static func partition<T: Sendable>(
        _ operations: [@Sendable () async throws -> T],
    ) async -> (successes: [T], failures: [Error]) {
        var successes: [T] = []
        var failures: [Error] = []

        await withTaskGroup(of: Result<T, Error>.self) { group in
            for operation in operations {
                group.addTask {
                    await ResultCapture.capture { try await operation() }
                }
            }

            for await result in group {
                switch result {
                case let .success(value):
                    successes.append(value)
                case let .failure(error):
                    failures.append(error)
                }
            }
        }

        return (successes, failures)
    }
}

// MARK: - Replacement Patterns for try?

/// Replacement for `try?` that logs errors
///
/// Instead of:
/// ```swift
/// let data = try? await fetchData()
/// ```
///
/// Use:
/// ```swift
/// let data = await tryOrNil(operation: "fetchData") {
///     try await fetchData()
/// }
/// ```
public func tryOrNil<T: Sendable>(
    operation: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    _ body: () async throws -> T,
) async -> T? {
    let result = await ResultCapture.capture(
        operation: operation,
        file: file,
        function: function,
        line: line,
        body,
    )
    return try? result.get()
}

/// Replacement for `try?` with default value
///
/// Instead of:
/// ```swift
/// let data = (try? await fetchData()) ?? defaultValue
/// ```
///
/// Use:
/// ```swift
/// let data = await tryOrDefault(defaultValue, operation: "fetchData") {
///     try await fetchData()
/// }
/// ```
public func tryOrDefault<T: Sendable>(
    _ defaultValue: @autoclosure () -> T,
    operation: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    _ body: () async throws -> T,
) async -> T {
    await tryOrNil(
        operation: operation,
        file: file,
        function: function,
        line: line,
        body,
    ) ?? defaultValue()
}
#endif

#endif
