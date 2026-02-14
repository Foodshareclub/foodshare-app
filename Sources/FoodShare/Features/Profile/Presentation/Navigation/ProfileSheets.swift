//
//  ProfileSheets.swift
//  FoodShare
//
//  Type-safe sheet presentation for Profile feature.
//  Centralizes all profile-related sheet state.
//

import SwiftUI

// MARK: - Profile Sheet Types

/// Type-safe enum for all sheets presentable from ProfileView
enum ProfileSheet: SheetPresentable {
    case avatarDetail(avatarUrl: String?)
    case qrCode(UserProfile)
    case appInfo

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .avatarDetail(url):
            hasher.combine("avatarDetail")
            hasher.combine(url)
        case let .qrCode(profile):
            hasher.combine("qrCode")
            hasher.combine(profile.id)
        case .appInfo:
            hasher.combine("appInfo")
        }
    }

    static func == (lhs: ProfileSheet, rhs: ProfileSheet) -> Bool {
        switch (lhs, rhs) {
        case let (.avatarDetail(lUrl), .avatarDetail(rUrl)):
            lUrl == rUrl
        case let (.qrCode(lProfile), .qrCode(rProfile)):
            lProfile.id == rProfile.id
        case (.appInfo, .appInfo):
            true
        default:
            false
        }
    }

    // MARK: - Content Builder

    @MainActor @ViewBuilder
    func makeContent() -> some View {
        switch self {
        case let .avatarDetail(avatarUrl):
            AvatarDetailView(avatarUrl: avatarUrl)
        case let .qrCode(profile):
            ProfileQRCodeView(profile: profile)
        case .appInfo:
            AppInfoSheet()
        }
    }
}

// MARK: - Profile Sheet Convenience

extension SheetCoordinator where Sheet == ProfileSheet {
    /// Present the avatar detail sheet
    func showAvatarDetail(avatarUrl: String?) {
        present(.avatarDetail(avatarUrl: avatarUrl))
    }

    /// Present the QR code sheet
    func showQRCode(for profile: UserProfile) {
        present(.qrCode(profile))
    }

    /// Present the app info sheet
    func showAppInfo() {
        present(.appInfo)
    }
}
