//
//  SheetCoordinator.swift
//  FoodShare
//
//  Centralized sheet management using type-safe coordinator pattern.
//  Reduces sheet state fragmentation across views.
//
//  Usage:
//  ```swift
//  @State private var sheetCoordinator = SheetCoordinator<ProfileSheet>()
//
//  Button("Show Profile") {
//      sheetCoordinator.present(.editProfile(viewModel))
//  }
//  .sheet(item: $sheetCoordinator.activeSheet) { sheet in
//      sheet.makeContent()
//  }
//  ```
//

import SwiftUI

// MARK: - Sheet Presentable Protocol

/// Protocol for type-safe sheet presentation.
/// Conform your sheet enums to this protocol to use with SheetCoordinator.
protocol SheetPresentable: Identifiable, Hashable {
    associatedtype Content: View

    /// Creates the view content for this sheet
    @MainActor @ViewBuilder func makeContent() -> Content
}

// MARK: - Default Identifiable Implementation

extension SheetPresentable {
    /// Default implementation uses the hash value for identity
    var id: Int { hashValue }
}

// MARK: - Sheet Coordinator

/// Type-safe coordinator for managing sheet presentation state.
///
/// Benefits:
/// - Centralizes all sheet state in one place
/// - Provides type-safe sheet presentation
/// - Reduces boilerplate `.sheet()` modifiers
/// - Integrates haptic feedback automatically
///
/// Example:
/// ```swift
/// enum ProfileSheet: SheetPresentable {
///     case editProfile(ProfileViewModel)
///     case avatarDetail(avatarUrl: String?)
///     case qrCode(UserProfile)
///
///     @ViewBuilder func makeContent() -> some View {
///         switch self {
///         case .editProfile(let vm): EditProfileSheet(viewModel: vm)
///         case .avatarDetail(let url): AvatarDetailView(avatarUrl: url)
///         case .qrCode(let profile): ProfileQRCodeView(profile: profile)
///         }
///     }
/// }
///
/// @State private var coordinator = SheetCoordinator<ProfileSheet>()
/// ```
@MainActor @Observable
final class SheetCoordinator<Sheet: SheetPresentable> {
    /// The currently active sheet, if any
    var activeSheet: Sheet?

    /// Whether haptic feedback is enabled for sheet transitions
    var hapticsEnabled: Bool

    /// Creates a new sheet coordinator
    /// - Parameter hapticsEnabled: Whether to trigger haptic feedback on present/dismiss
    init(hapticsEnabled: Bool = true) {
        self.hapticsEnabled = hapticsEnabled
    }

    /// Presents a sheet with optional haptic feedback
    /// - Parameter sheet: The sheet to present
    func present(_ sheet: Sheet) {
        if hapticsEnabled {
            HapticManager.light()
        }
        activeSheet = sheet
    }

    /// Dismisses the currently active sheet
    func dismiss() {
        activeSheet = nil
    }

    /// Returns true if a sheet is currently presented
    var isPresenting: Bool {
        activeSheet != nil
    }

    /// Presents a sheet if none is active, otherwise does nothing
    /// - Parameter sheet: The sheet to present
    /// - Returns: True if the sheet was presented
    @discardableResult
    func presentIfAvailable(_ sheet: Sheet) -> Bool {
        guard activeSheet == nil else { return false }
        present(sheet)
        return true
    }

    /// Replaces the current sheet with a new one
    /// - Parameter sheet: The new sheet to present
    func replace(with sheet: Sheet) {
        activeSheet = nil
        // Small delay to allow SwiftUI to process the dismissal
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            present(sheet)
        }
    }
}

// MARK: - View Extension for Sheet Coordinator

extension View {
    /// Presents a sheet managed by a SheetCoordinator
    /// - Parameter coordinator: The coordinator managing sheet state
    /// - Returns: A view that presents sheets based on coordinator state
    func sheet<Sheet: SheetPresentable>(
        coordinator: SheetCoordinator<Sheet>
    ) -> some View {
        self.sheet(item: Binding(
            get: { coordinator.activeSheet },
            set: { coordinator.activeSheet = $0 }
        )) { sheet in
            sheet.makeContent()
        }
    }

    /// Presents a full-screen cover managed by a SheetCoordinator
    /// - Parameter coordinator: The coordinator managing sheet state
    /// - Returns: A view that presents full-screen covers based on coordinator state
    func fullScreenCover<Sheet: SheetPresentable>(
        coordinator: SheetCoordinator<Sheet>
    ) -> some View {
        self.fullScreenCover(item: Binding(
            get: { coordinator.activeSheet },
            set: { coordinator.activeSheet = $0 }
        )) { sheet in
            sheet.makeContent()
        }
    }
}

// MARK: - Multi-Sheet Coordinator

/// Coordinator that can manage multiple types of sheets.
/// Useful when a view needs to present different sheet types.
@MainActor @Observable
final class MultiSheetCoordinator {
    /// Active sheet stored as Any to support multiple types
    private var _activeSheet: (any SheetPresentable)?

    /// Type-erased active sheet for binding
    var hasActiveSheet: Bool { _activeSheet != nil }

    /// Presents a sheet of any conforming type
    func present<S: SheetPresentable>(_ sheet: S) {
        HapticManager.light()
        _activeSheet = sheet
    }

    /// Dismisses the current sheet
    func dismiss() {
        _activeSheet = nil
    }

    /// Gets the active sheet if it matches the expected type
    func activeSheet<S: SheetPresentable>(as type: S.Type) -> S? {
        _activeSheet as? S
    }
}
