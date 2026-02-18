//
//  LocaleUtilities.swift
//  Foodshare
//
//  Utilities for locale handling and display
//


#if !SKIP
import Foundation

/// Utilities for working with locales
enum LocaleUtilities {
    /// Mapping of locale codes to flag emojis
    static let flagEmojis: [String: String] = [
        "en": "🇬🇧",
        "cs": "🇨🇿",
        "de": "🇩🇪",
        "es": "🇪🇸",
        "fr": "🇫🇷",
        "pt": "🇵🇹",
        "ru": "🇷🇺",
        "uk": "🇺🇦",
        "zh": "🇨🇳",
        "hi": "��🇳",
        "ar": "🇸🇦",
        "it": "🇮🇹",
        "pl": "🇵🇱",
        "nl": "🇳🇱",
        "ja": "🇯🇵",
        "ko": "🇰🇷",
        "tr": "🇹🇷",
    ]
    
    /// Get flag emoji for a locale code
    /// - Parameter locale: Locale code (e.g., "en", "es")
    /// - Returns: Flag emoji or globe emoji if not found
    static func flagEmoji(for locale: String) -> String {
        flagEmojis[locale] ?? "🌐"
    }
    
    /// Get localized language name for a locale code
    /// - Parameter locale: Locale code (e.g., "en", "es")
    /// - Returns: Localized language name (e.g., "English", "Español")
    static func localizedLanguageName(for locale: String) -> String {
        let localeObj = Locale(identifier: locale)
        return localeObj.localizedString(forLanguageCode: locale)?.capitalized
            ?? locale.uppercased()
    }
}

#endif
