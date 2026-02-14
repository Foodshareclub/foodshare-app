//
//  AutoTranslateModifier.swift
//  Foodshare
//
//  Auto-translates content for non-English locales using self-hosted LLM
//  with 3-layer caching (Memory -> Database -> LLM)
//

import FoodShareDesignSystem
import OSLog
import Supabase
import SwiftUI

private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AutoTranslate")

// MARK: - Auto Translate Response

/// Response from translate-content endpoint
private struct TranslateResponse: Codable {
    let success: Bool
    let translatedText: String?
    let cached: Bool?
    let cacheLayer: String?
    let quality: Double?
    let responseTimeMs: Int?
    let error: String?
}

// MARK: - Auto Translate Modifier

/// View modifier that auto-translates text for non-English locales
struct AutoTranslateModifier: ViewModifier {
    // MARK: - Properties

    let originalText: String
    let contentType: String
    @Binding var translatedText: String
    @Binding var isTranslated: Bool

    @Environment(\.translationService) private var t
    @State private var isLoading = false

    // MARK: - Task Management

    @State private var translateTask: Task<Void, Never>?

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            // Re-trigger translation when text, locale, OR revision changes
            .task(id: "\(originalText)_\(t.currentLocale)_\(t.translationRevision)") {
                await autoTranslate()
            }
            .onDisappear {
                translateTask?.cancel()
            }
    }

    // MARK: - Translation

    @MainActor
    private func autoTranslate() async {
        // Cancel any pending translation to prevent duplicates
        translateTask?.cancel()

        // Skip for English or empty text
        guard t.currentLocale != "en", !originalText.isEmpty else {
            translatedText = originalText
            isTranslated = false // Reset when in English
            return
        }

        // Debounce rapid locale changes (300ms)
        translateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await performTranslation()
        }
    }

    @MainActor
    private func performTranslation() async {
        guard !Task.isCancelled else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await LocalizationAPIService.shared.translate(
                text: originalText,
                targetLanguage: t.currentLocale
            )

            guard !Task.isCancelled else { return }

            translatedText = result.translatedText
                logger.debug("AutoTranslate success for \(self.contentType): \(text.prefix(30))...")
                withAnimation(.easeInOut(duration: 0.2)) {
                    translatedText = text
                    isTranslated = true
                }
            } else {
                logger.warning("AutoTranslate failed: \(result.error ?? "unknown")")
                translatedText = originalText
                isTranslated = false
            }
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("AutoTranslate error: \(error.localizedDescription)")
            // Fallback to original text
            translatedText = originalText
            isTranslated = false
        }
    }
}

// MARK: - View Extension

extension View {
    /// Automatically translates content for non-English locales
    /// - Parameters:
    ///   - original: The original English text to translate
    ///   - contentType: Content type for translation context (e.g., "listing", "forum_post", "challenge")
    ///   - translated: Binding to store the translated text
    ///   - isTranslated: Binding to track if translation occurred
    /// - Returns: Modified view with auto-translation capability
    func autoTranslate(
        original: String,
        contentType: String = "general",
        translated: Binding<String>,
        isTranslated: Binding<Bool>,
    ) -> some View {
        modifier(AutoTranslateModifier(
            originalText: original,
            contentType: contentType,
            translatedText: translated,
            isTranslated: isTranslated,
        ))
    }
}

// MARK: - Preview

#Preview("Auto Translate Modifier") {
    @Previewable @State var displayText = "Fresh organic apples from my garden"
    @Previewable @State var isTranslated = false

    VStack(spacing: Spacing.md) {
        Text("Auto-Translation Demo")
            .font(.DesignSystem.headlineMedium)
            .foregroundColor(.DesignSystem.textPrimary)

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(displayText)
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.textSecondary)

            if isTranslated {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                    Text("Translated from English")
                        .font(.DesignSystem.caption)
                }
                .foregroundColor(.DesignSystem.textTertiary)
            }
        }
        .autoTranslate(
            original: "Fresh organic apples from my garden",
            contentType: "listing",
            translated: $displayText,
            isTranslated: $isTranslated,
        )
        .padding()
        .background(Color.DesignSystem.glassBackground)
        .cornerRadius(CornerRadius.medium)
    }
    .padding()
    .background(Color.DesignSystem.background)
}
