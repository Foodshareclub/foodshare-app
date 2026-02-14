//
//  PluralRules.swift
//  Foodshare
//
//  CLDR-based plural rules for all supported locales.
//  Reference: https://cldr.unicode.org/index/cldr-spec/plural-rules
//

import Foundation

// MARK: - Plural Category

public enum PluralCategory: String, Sendable, CaseIterable {
    case zero
    case one
    case two
    case few
    case many
    case other
}

// MARK: - Plural Rules

/// CLDR-based plural rules for supported locales.
public enum PluralRules {
    /// Returns the plural category for a count in the given locale.
    public static func category(for count: Int, locale: String) -> PluralCategory {
        let n = abs(count)

        switch locale {
        case "zh", "ja", "ko", "vi", "id", "th":
            return .other
        case "ar":
            return arabicPlural(n)
        case "ru", "uk":
            return slavicPlural(n)
        case "pl":
            return polishPlural(n)
        case "cs":
            return czechPlural(n)
        default:
            return n == 1 ? .one : .other
        }
    }
    
    /// Returns ordinal category (1st, 2nd, 3rd, etc.)
    public static func ordinal(for n: Int, locale: String) -> PluralCategory {
        switch locale {
        case "en":
            let mod10 = n % 10
            let mod100 = n % 100
            if mod10 == 1 && mod100 != 11 { return .one }      // 1st, 21st
            if mod10 == 2 && mod100 != 12 { return .two }      // 2nd, 22nd
            if mod10 == 3 && mod100 != 13 { return .few }      // 3rd, 23rd
            return .other                                        // 4th, 11th
        default:
            return .other
        }
    }

    private static func arabicPlural(_ n: Int) -> PluralCategory {
        if n == 0 { return .zero }
        if n == 1 { return .one }
        if n == 2 { return .two }
        let mod100 = n % 100
        if mod100 >= 3 && mod100 <= 10 { return .few }
        if mod100 >= 11 { return .many }
        return .other
    }

    private static func slavicPlural(_ n: Int) -> PluralCategory {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return .one }
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) { return .few }
        return .many
    }

    private static func polishPlural(_ n: Int) -> PluralCategory {
        if n == 1 { return .one }
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) { return .few }
        return .many
    }

    private static func czechPlural(_ n: Int) -> PluralCategory {
        if n == 1 { return .one }
        if n >= 2 && n <= 4 { return .few }
        return .other
    }
}

// MARK: - EnhancedTranslationService Extension

extension EnhancedTranslationService {
    /// Returns pluralized translation using CLDR rules.
    public func plural(_ key: String, count: Int) -> String {
        let category = PluralRules.category(for: count, locale: currentLocale)
        let pluralKey = "\(key).\(category.rawValue)"
        
        var result = t(pluralKey)
        if result == pluralKey {
            result = t("\(key).other")
        }
        return result.replacingOccurrences(of: "{count}", with: String(count))
    }
    
    /// Returns ordinal translation (1st, 2nd, 3rd...)
    public func ordinal(_ key: String, n: Int) -> String {
        let category = PluralRules.ordinal(for: n, locale: currentLocale)
        let ordinalKey = "\(key).\(category.rawValue)"
        
        var result = t(ordinalKey)
        if result == ordinalKey {
            result = t("\(key).other")
        }
        return result.replacingOccurrences(of: "{n}", with: String(n))
    }
    
    /// Smart plural with formatted number
    public func pluralFormatted(_ key: String, count: Int) -> String {
        let formatted = formatNumber(Double(count), style: .decimal)
        return plural(key, count: count).replacingOccurrences(of: String(count), with: formatted)
    }
}

// MARK: - Gender Support

public enum GrammaticalGender: String, Sendable {
    case masculine, feminine, neutral
}

extension EnhancedTranslationService {
    /// Gender-aware translation
    public func t(_ key: String, gender: GrammaticalGender) -> String {
        let genderedKey = "\(key).\(gender.rawValue)"
        let result = t(genderedKey)
        return result != genderedKey ? result : t(key)
    }
    
    /// Format a list according to locale (e.g., "A, B, and C")
    public func formatList(_ items: [String], type: ListType = .and) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        
        let formatter = ListFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        
        // ListFormatter uses "and" by default
        if let formatted = formatter.string(from: items) {
            if type == .or {
                // Replace "and" with "or" for the current locale
                let andWord = t("common.and")
                let orWord = t("common.or")
                return formatted.replacingOccurrences(of: " \(andWord) ", with: " \(orWord) ")
            }
            return formatted
        }
        return items.joined(separator: ", ")
    }
    
    public enum ListType { case and, or }
}

// MARK: - ICU Select Support

extension EnhancedTranslationService {
    /// ICU select: choose translation based on value
    /// Key format: "key.value1", "key.value2", "key.other"
    public func select(_ key: String, value: String) -> String {
        let selectKey = "\(key).\(value)"
        let result = t(selectKey)
        return result != selectKey ? result : t("\(key).other")
    }
    
    /// Range formatting (e.g., "1-5 items")
    public func formatRange(_ lower: Int, _ upper: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        formatter.numberStyle = .decimal
        
        let lowerStr = formatter.string(from: NSNumber(value: lower)) ?? "\(lower)"
        let upperStr = formatter.string(from: NSNumber(value: upper)) ?? "\(upper)"
        
        // Use locale-appropriate range separator
        return "\(lowerStr)–\(upperStr)"
    }
    
    /// Percentage formatting
    public func formatPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }
    
    /// Duration formatting (e.g., "2h 30m")
    public func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.calendar?.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        return formatter.string(from: seconds) ?? ""
    }
}
