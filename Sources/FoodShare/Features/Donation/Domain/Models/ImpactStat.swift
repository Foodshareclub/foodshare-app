//
//  ImpactStat.swift
//  Foodshare
//
//  Domain model for donation impact statistics
//


#if !SKIP
import Foundation
import SwiftUI

/// Represents an impact statistic for the donation page
struct ImpactStat: Identifiable, Sendable {
    let id = UUID()
    let value: String
    let title: String
    let description: String
    let icon: String
    let color: Color

    /// Returns localized impact stats using the provided translation service
    @MainActor static func localizedStats(using t: EnhancedTranslationService) -> [ImpactStat] {
        [
            ImpactStat(
                value: t.t("donation.impact.direct.value"),
                title: t.t("donation.impact.direct.title"),
                description: t.t("donation.impact.direct.desc"),
                icon: "heart.fill",
                color: .DesignSystem.accentPink
            ),
            ImpactStat(
                value: t.t("donation.impact.lives.value"),
                title: t.t("donation.impact.lives.title"),
                description: t.t("donation.impact.lives.desc"),
                icon: "person.3.fill",
                color: .DesignSystem.brandBlue
            ),
            ImpactStat(
                value: t.t("donation.impact.zero.value"),
                title: t.t("donation.impact.zero.title"),
                description: t.t("donation.impact.zero.desc"),
                icon: "leaf.fill",
                color: .DesignSystem.brandGreen
            )
        ]
    }
}

#endif
