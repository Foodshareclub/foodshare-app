//
//  LogEntry.swift
//  Foodshare
//
//  Structured log entry model with JSON serialization
//

import Foundation

/// A structured log entry for persistence and analysis
struct LogEntry: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
    let category: String
    let file: String
    let function: String
    let line: Int
    let context: [String: AnyCodable]?
    let errorDescription: String?
    let errorType: String?
    let deviceInfo: DeviceInfo?

    /// Compact device information for log context
    struct DeviceInfo: Codable, Sendable {
        let osVersion: String
        let appVersion: String
        let buildNumber: String
        let deviceModel: String

        static let current: DeviceInfo = {
            let info = Bundle.main.infoDictionary
            return DeviceInfo(
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
                buildNumber: info?["CFBundleVersion"] as? String ?? "unknown",
                deviceModel: Self.deviceModelIdentifier(),
            )
        }()

        private static func deviceModelIdentifier() -> String {
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            let identifier = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
            return identifier
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        message: String,
        category: String = "app",
        file: String,
        function: String,
        line: Int,
        context: [String: AnyCodable]? = nil,
        error: Error? = nil,
        includeDeviceInfo: Bool = false,
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.category = category
        self.file = file
        self.function = function
        self.line = line
        self.context = context
        self.errorDescription = error?.localizedDescription
        self.errorType = error.map { String(describing: type(of: $0)) }
        self.deviceInfo = includeDeviceInfo ? .current : nil
    }

    /// JSON representation for export
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Human-readable single-line format for console
    var consoleFormat: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = dateFormatter.string(from: timestamp)
        let location = "[\(file):\(line)]"
        let errorSuffix = errorDescription.map { " | Error: \($0)" } ?? ""
        return "\(level.consoleColor)[\(level.rawValue)]\(LogLevel.colorReset) \(timestamp) \(location) \(function) - \(message)\(errorSuffix)"
    }
}

// Note: AnyCodable is defined in FoodShare/Core/Services/PostActivityService.swift
// and is used for flexible context values in log entries
