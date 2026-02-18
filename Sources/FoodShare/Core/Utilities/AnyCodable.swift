//
//  AnyCodable.swift
//  Foodshare
//
//  Type-erasing wrapper for any Codable value.
//  Provides backward compatibility for logging and analytics.
//

import Foundation

#if !SKIP

/// A type-erasing wrapper that can encode any value for JSON serialization.
/// Used for logging context and analytics where the value types are heterogeneous.
public struct AnyCodable: Codable, Sendable, CustomStringConvertible, Hashable {
    private let value: any Sendable
    private let encode: @Sendable (any Encoder) throws -> Void
    private let hashValue_: Int

    public init(_ value: some Codable & Sendable) {
        self.value = value
        self.encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        self.hashValue_ = String(describing: value).hashValue
    }

    public init(_ value: String) {
        self.value = value
        self.encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        self.hashValue_ = value.hashValue
    }

    public init(_ value: Int) {
        self.value = value
        self.encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        self.hashValue_ = value.hashValue
    }

    public init(_ value: Double) {
        self.value = value
        self.encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        self.hashValue_ = value.hashValue
    }

    public init(_ value: Bool) {
        self.value = value
        self.encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        self.hashValue_ = value.hashValue
    }

    public init(_ value: [AnyCodable]) {
        self.value = value
        self.encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        self.hashValue_ = value.hashValue
    }

    public init(_ value: [String: AnyCodable]) {
        self.value = value
        self.encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        self.hashValue_ = value.keys.sorted().hashValue
    }

    public func encode(to encoder: any Encoder) throws {
        try encode(encoder)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.init("null")
        } else if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let double = try? container.decode(Double.self) {
            self.init(double)
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.init(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.init(dict)
        } else {
            self.init("null")
        }
    }

    public var description: String {
        String(describing: value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashValue_)
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        lhs.description == rhs.description
    }

    // MARK: - Typed Accessors

    /// Extract as String
    public var stringValue: String? {
        value as? String
    }

    /// Extract as Int
    public var intValue: Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        return nil
    }

    /// Extract as Double
    public var doubleValue: Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        return nil
    }

    /// Extract as Bool
    public var boolValue: Bool? {
        value as? Bool
    }

    /// Extract as array of AnyCodable
    public var arrayValue: [AnyCodable]? {
        value as? [AnyCodable]
    }

    /// Extract as string array (common for JSONB arrays like languages)
    public var stringArrayValue: [String]? {
        (value as? [AnyCodable])?.compactMap(\.stringValue)
    }

    /// Extract as dictionary
    public var dictionaryValue: [String: AnyCodable]? {
        value as? [String: AnyCodable]
    }
}

#else

/// Simplified AnyCodable for Android/Skip.
/// Stores string representation for cross-platform compatibility.
public struct AnyCodable: Codable, Hashable {
    private let stringRepresentation: String

    public init(_ value: String) { self.stringRepresentation = value }
    public init(_ value: Int) { self.stringRepresentation = String(value) }
    public init(_ value: Double) { self.stringRepresentation = String(value) }
    public init(_ value: Bool) { self.stringRepresentation = String(value) }
    public init(_ value: some Codable) { self.stringRepresentation = String(describing: value) }
    public init(_ value: [AnyCodable]) {
        var parts: [String] = []
        for item in value { parts.append(item.stringRepresentation) }
        self.stringRepresentation = "[\(parts.joined(separator: ","))]"
    }
    public init(_ value: [String: AnyCodable]) { self.stringRepresentation = String(describing: value) }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.stringRepresentation = string
        } else if let int = try? container.decode(Int.self) {
            self.stringRepresentation = String(int)
        } else if let double = try? container.decode(Double.self) {
            self.stringRepresentation = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            self.stringRepresentation = String(bool)
        } else {
            self.stringRepresentation = "null"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringRepresentation)
    }

    public var stringValue: String? { stringRepresentation }
    public var intValue: Int? { Int(stringRepresentation) }
    public var doubleValue: Double? { Double(stringRepresentation) }
    public var boolValue: Bool? { stringRepresentation == "true" ? true : (stringRepresentation == "false" ? false : nil) }
    public var arrayValue: [AnyCodable]? { nil }
    public var stringArrayValue: [String]? { nil }
    public var dictionaryValue: [String: AnyCodable]? { nil }
}

#endif
