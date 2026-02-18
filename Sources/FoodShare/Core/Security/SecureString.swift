//
//  SecureString.swift
//  FoodShare
//
//  Memory-safe string handling that zeros memory on deallocation.
//  Use for passwords, tokens, API keys, and other sensitive strings.
//
//  Usage:
//  ```swift
//  let password = SecureString("my-password")
//  // Use password.value when needed
//  // Memory is automatically zeroed when SecureString is deallocated
//
//  // Or use the convenience accessor:
//  password.use { plaintext in
//      authenticate(with: plaintext)
//  }
//  ```
//


#if !SKIP
import Foundation

// MARK: - Secure String

/// A string wrapper that securely zeros memory on deallocation
/// Use for passwords, tokens, API keys, and other sensitive strings
final class SecureString: @unchecked Sendable {

    // MARK: - Properties

    /// Internal UTF-8 bytes storage
    private var bytes: [UInt8]

    /// Whether the memory has been zeroed
    private var isZeroed = false

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// The string value (computed on demand to minimize exposure)
    var value: String {
        lock.lock()
        defer { lock.unlock() }
        guard !isZeroed else { return "" }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    /// Number of characters
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return bytes.count
    }

    /// Whether the string is empty
    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return bytes.isEmpty
    }

    // MARK: - Initialization

    /// Initialize with a string value
    /// - Parameter string: The sensitive string to store
    init(_ string: String) {
        bytes = Array(string.utf8)
    }

    /// Initialize with raw bytes
    /// - Parameter bytes: UTF-8 bytes of the string
    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    /// Initialize with Data
    /// - Parameter data: UTF-8 encoded string data
    init(data: Data) {
        bytes = Array(data)
    }

    deinit {
        secureZero()
    }

    // MARK: - Public API

    /// Safely use the string value and immediately discard
    /// - Parameter block: Closure that receives the plaintext string
    /// - Returns: The result of the block
    func use<T>(_ block: (String) throws -> T) rethrows -> T {
        lock.lock()
        let val = String(bytes: bytes, encoding: .utf8) ?? ""
        lock.unlock()
        return try block(val)
    }

    /// Safely use the bytes and immediately discard
    /// - Parameter block: Closure that receives the raw bytes
    /// - Returns: The result of the block
    func useBytes<T>(_ block: ([UInt8]) throws -> T) rethrows -> T {
        lock.lock()
        let bytesCopy = bytes
        lock.unlock()
        return try block(bytesCopy)
    }

    /// Appends another secure string
    /// - Parameter other: The string to append
    func append(_ other: SecureString) {
        lock.lock()
        defer { lock.unlock() }
        other.lock.lock()
        defer { other.lock.unlock() }
        bytes.append(contentsOf: other.bytes)
    }

    /// Appends a regular string
    /// - Parameter string: The string to append
    func append(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        bytes.append(contentsOf: string.utf8)
    }

    /// Creates a copy of this secure string
    /// - Returns: A new SecureString with the same content
    func copy() -> SecureString {
        lock.lock()
        defer { lock.unlock() }
        return SecureString(bytes: bytes)
    }

    /// Manually zero the memory (also called automatically on deinit)
    func secureZero() {
        lock.lock()
        defer { lock.unlock() }
        guard !isZeroed, !bytes.isEmpty else { return }

        // Zero each byte explicitly
        for i in bytes.indices {
            bytes[i] = 0
        }

        // Clear the array
        bytes.removeAll()
        isZeroed = true
    }

    /// Converts to Data (creates a copy)
    /// - Returns: Data representation of the string
    func toData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return Data(bytes)
    }

    // MARK: - Private Thread-Safe Accessors

    private var threadSafeBytes: [UInt8] {
        lock.lock()
        defer { lock.unlock() }
        return bytes
    }

    private var threadSafeIsZeroed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isZeroed
    }
}

// MARK: - Equatable

extension SecureString: Equatable {
    static func == (lhs: SecureString, rhs: SecureString) -> Bool {
        let lhsBytes = lhs.threadSafeBytes
        let rhsBytes = rhs.threadSafeBytes

        // Constant-time comparison to prevent timing attacks
        guard lhsBytes.count == rhsBytes.count else { return false }

        var result: UInt8 = 0
        for (a, b) in zip(lhsBytes, rhsBytes) {
            result |= a ^ b
        }
        return result == 0
    }
}

// MARK: - Hashable

extension SecureString: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(threadSafeBytes)
    }
}

// MARK: - Custom String Convertible

extension SecureString: CustomStringConvertible {
    var description: String {
        "[SecureString: \(count) bytes]"
    }
}

// MARK: - Custom Debug String Convertible

extension SecureString: CustomDebugStringConvertible {
    var debugDescription: String {
        "[SecureString: \(count) bytes, zeroed: \(threadSafeIsZeroed)]"
    }
}

// MARK: - Secure Bytes

/// A byte array wrapper that securely zeros memory on deallocation
/// Use for encryption keys, nonces, and other sensitive binary data
final class SecureBytes: @unchecked Sendable {

    // MARK: - Properties

    private var bytes: [UInt8]
    private var isZeroed = false
    private let lock = NSLock()

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return bytes.count
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return bytes.isEmpty
    }

    // MARK: - Initialization

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    init(count: Int) {
        bytes = [UInt8](repeating: 0, count: count)
    }

    init(data: Data) {
        bytes = Array(data)
    }

    deinit {
        secureZero()
    }

    // MARK: - Public API

    /// Safely access the bytes
    func use<T>(_ block: ([UInt8]) throws -> T) rethrows -> T {
        lock.lock()
        let bytesCopy = bytes
        lock.unlock()
        return try block(bytesCopy)
    }

    /// Safely access as mutable bytes
    func useMutable<T>(_ block: (inout [UInt8]) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try block(&bytes)
    }

    /// Convert to Data (creates a copy)
    func toData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return Data(bytes)
    }

    /// Manually zero the memory
    func secureZero() {
        lock.lock()
        defer { lock.unlock() }
        guard !isZeroed, !bytes.isEmpty else { return }

        for i in bytes.indices {
            bytes[i] = 0
        }
        bytes.removeAll()
        isZeroed = true
    }

    /// Fill with cryptographically random bytes
    func fillWithRandom() {
        lock.lock()
        defer { lock.unlock() }
        var randomBytes = bytes
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if result == errSecSuccess {
            bytes = randomBytes
        }
    }

    /// Create with random bytes
    static func random(count: Int) -> SecureBytes {
        let secure = SecureBytes(count: count)
        secure.fillWithRandom()
        return secure
    }
}

// MARK: - String Extension for Secure Conversion

extension String {
    /// Creates a SecureString from this string
    /// Note: The original String still exists in memory - use SecureString from the start when possible
    var secure: SecureString {
        SecureString(self)
    }
}

// MARK: - Data Extension for Secure Conversion

extension Data {
    /// Creates SecureBytes from this data
    var secure: SecureBytes {
        SecureBytes(data: self)
    }

    /// Securely zeros the data in place
    mutating func secureZero() {
        guard !isEmpty else { return }
        withUnsafeMutableBytes { buffer in
            if let baseAddress = buffer.baseAddress {
                memset(baseAddress, 0, buffer.count)
            }
        }
    }
}

#endif
