//
//  LocalizationEnvironment.swift
//  Foodshare
//
//  SwiftUI environment integration for reactive localization.
//


#if !SKIP
import SwiftUI

// MARK: - Global Convenience Function

/// Global translation function for use anywhere in the app.
/// Usage: `localized("common.loading")` or `localized("greeting", ["name": "John"])`
@MainActor
public func localized(_ key: String) -> String {
    EnhancedTranslationService.shared.t(key)
}

@MainActor
public func localized(_ key: String, _ args: [String: String]) -> String {
    EnhancedTranslationService.shared.t(key, args: args)
}

@MainActor
public func localized(_ namespace: TranslationNamespace, _ key: String) -> String {
    EnhancedTranslationService.shared.t(namespace, key)
}

// MARK: - Localized Text View

/// A Text view that automatically updates when the locale changes.
public struct LocalizedText: View {
    private let key: String
    private let args: [String: String]?

    @Environment(\.translationService) private var t

    public init(_ key: String) {
        self.key = key
        self.args = nil
    }

    public init(_ key: String, args: [String: String]) {
        self.key = key
        self.args = args
    }

    public var body: some View {
        let _ = t.translationRevision
        if let args {
            Text(t.t(key, args: args))
        } else {
            Text(t.t(key))
        }
    }
}

// MARK: - Localized Button

/// A Button with localized title that updates when locale changes.
public struct LocalizedButton: View {
    private let key: String
    private let action: () -> Void
    
    @Environment(\.translationService) private var t
    
    public init(_ key: String, action: @escaping () -> Void) {
        self.key = key
        self.action = action
    }
    
    public var body: some View {
        let _ = t.translationRevision
        Button(t.t(key), action: action)
    }
}

// MARK: - Localized Label

/// A Label with localized title that updates when locale changes.
public struct LocalizedLabel: View {
    private let key: String
    private let systemImage: String
    
    @Environment(\.translationService) private var t
    
    public init(_ key: String, systemImage: String) {
        self.key = key
        self.systemImage = systemImage
    }
    
    public var body: some View {
        let _ = t.translationRevision
        Label(t.t(key), systemImage: systemImage)
    }
}

// MARK: - Localized View Modifier

struct LocalizationObserver: ViewModifier {
    @Environment(\.translationService) private var translationService

    func body(content: Content) -> some View {
        let _ = translationService.translationRevision
        content
    }
}

extension View {
    public func observeLocalization() -> some View {
        modifier(LocalizationObserver())
    }
    
    /// Sets navigation title with localized string
    public func localizedNavigationTitle(_ key: String) -> some View {
        modifier(LocalizedNavigationTitle(key: key))
    }
    
    /// Applies RTL layout direction based on current locale
    public func localizedLayoutDirection() -> some View {
        modifier(LocalizedLayoutDirection())
    }
}

struct LocalizedNavigationTitle: ViewModifier {
    let key: String
    @Environment(\.translationService) private var t
    
    func body(content: Content) -> some View {
        let _ = t.translationRevision
        content.navigationTitle(t.t(key))
    }
}

struct LocalizedLayoutDirection: ViewModifier {
    @Environment(\.translationService) private var t
    
    func body(content: Content) -> some View {
        let _ = t.translationRevision
        content.environment(\.layoutDirection, t.isRTL ? .rightToLeft : .leftToRight)
    }
}

// MARK: - String Extension

extension String {
    @MainActor
    public var localized: String {
        EnhancedTranslationService.shared.t(self)
    }

    @MainActor
    public func localized(with args: [String: String]) -> String {
        EnhancedTranslationService.shared.t(self, args: args)
    }
    
    @MainActor
    public func localized(context: String) -> String {
        EnhancedTranslationService.shared.t(self, context: context)
    }
    
    @MainActor
    public func localized(fallback: String) -> String {
        EnhancedTranslationService.shared.t(self, fallback: fallback)
    }
}

// MARK: - Property Wrapper

/// Property wrapper for localized strings in ViewModels
@propertyWrapper
public struct Localized: DynamicProperty {
    private let key: String
    
    public init(_ key: String) {
        self.key = key
    }
    
    @MainActor
    public var wrappedValue: String {
        EnhancedTranslationService.shared.t(key)
    }
}

// MARK: - Accessibility Helpers

extension View {
    /// Adds localized accessibility label
    public func localizedAccessibilityLabel(_ key: String) -> some View {
        modifier(LocalizedAccessibilityLabel(key: key))
    }
    
    /// Adds localized accessibility hint
    public func localizedAccessibilityHint(_ key: String) -> some View {
        modifier(LocalizedAccessibilityHint(key: key))
    }
}

struct LocalizedAccessibilityLabel: ViewModifier {
    let key: String
    @Environment(\.translationService) private var t
    
    func body(content: Content) -> some View {
        let _ = t.translationRevision
        content.accessibilityLabel(t.t(key))
    }
}

struct LocalizedAccessibilityHint: ViewModifier {
    let key: String
    @Environment(\.translationService) private var t
    
    func body(content: Content) -> some View {
        let _ = t.translationRevision
        content.accessibilityHint(t.t(key))
    }
}

// MARK: - Pluralized Text View

/// Text view with automatic pluralization
public struct PluralText: View {
    private let key: String
    private let count: Int
    
    @Environment(\.translationService) private var t
    
    public init(_ key: String, count: Int) {
        self.key = key
        self.count = count
    }
    
    public var body: some View {
        let _ = t.translationRevision
        Text(t.plural(key, count: count))
    }
}

// MARK: - Relative Time Text

/// Text view showing relative time that updates
public struct RelativeTimeText: View {
    private let date: Date
    
    @Environment(\.translationService) private var t
    
    public init(_ date: Date) {
        self.date = date
    }
    
    public var body: some View {
        let _ = t.translationRevision
        Text(t.formatRelativeTime(date))
    }
}

// MARK: - Interpolation Builder

/// Fluent API for building translations with multiple arguments
@MainActor
public struct TranslationBuilder {
    private let key: String
    private var args: [String: String] = [:]
    
    public init(_ key: String) {
        self.key = key
    }
    
    public func arg(_ name: String, _ value: String) -> TranslationBuilder {
        var copy = self
        copy.args[name] = value
        return copy
    }
    
    public func arg(_ name: String, _ value: Int) -> TranslationBuilder {
        arg(name, String(value))
    }
    
    public func arg(_ name: String, _ value: Double) -> TranslationBuilder {
        arg(name, EnhancedTranslationService.shared.formatNumber(value))
    }
    
    public var string: String {
        EnhancedTranslationService.shared.t(key, args: args)
    }
    
    public var text: Text {
        Text(string)
    }
}

/// Shorthand for TranslationBuilder
@MainActor
public func L(_ key: String) -> TranslationBuilder {
    TranslationBuilder(key)
}

// MARK: - Debug Overlay

#if DEBUG
/// Shows translation keys instead of values for debugging
public struct TranslationDebugOverlay: ViewModifier {
    @Environment(\.translationService) private var t
    @State private var showKeys = false
    
    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if showKeys {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("🌐 \(t.currentLocale.uppercased())")
                        Text("\(t.translationCount) keys")
                        Text("\(t.missingTranslationKeys.count) missing")
                    }
                    .font(.caption2)
                    .padding(6)
                    #if !SKIP
                    .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .background(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .cornerRadius(CornerRadius.small)
                    .padding(8)
                }
            }
            .onShake {
                showKeys.toggle()
            }
    }
}

extension View {
    /// Adds debug overlay showing locale info (shake to toggle)
    public func translationDebugOverlay() -> some View {
        modifier(TranslationDebugOverlay())
    }
}

// Shake gesture detection
extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        #if !SKIP
        self.onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            action()
        }
        #else
        self
        #endif
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}
#endif

// MARK: - Markdown Translation

extension EnhancedTranslationService {
    /// Returns attributed string with markdown support
    @MainActor
    public func markdown(_ key: String) -> AttributedString {
        let text = t(key)
        return (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
    
    /// Returns attributed string with markdown and args
    @MainActor
    public func markdown(_ key: String, args: [String: String]) -> AttributedString {
        let text = t(key, args: args)
        return (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

/// Text view with markdown support
public struct LocalizedMarkdown: View {
    private let key: String
    private let args: [String: String]?
    
    @Environment(\.translationService) private var t
    
    public init(_ key: String) {
        self.key = key
        self.args = nil
    }
    
    public init(_ key: String, args: [String: String]) {
        self.key = key
        self.args = args
    }
    
    public var body: some View {
        let _ = t.translationRevision
        if let args {
            Text(t.markdown(key, args: args))
        } else {
            Text(t.markdown(key))
        }
    }
}

// MARK: - Sync Status View

/// Shows translation sync status
public struct TranslationSyncStatus: View {
    @Environment(\.translationService) private var t
    
    public init() {}
    
    public var body: some View {
        let _ = t.translationRevision
        HStack(spacing: 4) {
            switch t.state {
            case .syncing:
                ProgressView().scaleEffect(0.7)
                Text(t.t("common.syncing"))
            case .offline:
                Image(systemName: "wifi.slash")
                Text(t.t("common.offline"))
            case .error:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Locale Picker

/// Compact locale picker button
public struct LocalePickerButton: View {
    @Environment(\.translationService) private var t
    @State private var showPicker = false
    
    public init() {}
    
    public var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 4) {
                Text(t.currentLocaleInfo?.flag ?? "🌐")
                Text(t.currentLocale.uppercased())
                    .font(.caption.bold())
            }
        }
        .sheet(isPresented: $showPicker) {
            LocalePickerSheet()
        }
    }
}

struct LocalePickerSheet: View {
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss: DismissAction
    @State private var isChanging = false
    
    var body: some View {
        NavigationStack {
            List(t.supportedLocales) { locale in
                Button {
                    Task {
                        isChanging = true
                        try? await t.setLocale(locale.code)
                        isChanging = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        Text(locale.flag)
                        Text(locale.nativeName)
                        Spacer()
                        if locale.code == t.currentLocale {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .disabled(isChanging)
            }
            .navigationTitle(t.t("settings.language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) { dismiss() }
                }
            }
            .overlay {
                if isChanging {
                    ProgressView()
                }
            }
        }
    }
}

#endif
