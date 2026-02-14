//
//  CommunityFridgeDetailView.swift
//  Foodshare
//
//  Detail view for a community fridge
//

import FoodShareDesignSystem
#if !SKIP
import MapKit
#endif
import SwiftUI

struct CommunityFridgeDetailView: View {

    @Environment(\.translationService) private var t
    let fridge: CommunityFridge
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showReportIssue = false
    @State private var reportIssueType: ReportIssueType?
    @State private var sectionsAppeared = false
    @State private var isLoading = true
    @State private var displayDescription = ""
    @State private var isDescriptionTranslated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum ReportIssueType: String, CaseIterable, Identifiable {
        case damaged = "Fridge Damaged"
        case cleanlinessIssue = "Cleanliness Issue"
        case accessProblem = "Access Problem"
        case safetyHazard = "Safety Hazard"
        case other = "Other"

        var id: String {
            rawValue
        }

        var icon: String {
            switch self {
            case .damaged: "wrench.and.screwdriver.fill"
            case .cleanlinessIssue: "sparkles"
            case .accessProblem: "lock.fill"
            case .safetyHazard: "exclamationmark.triangle.fill"
            case .other: "ellipsis.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    GlassDetailSkeleton(style: .communityFridge, showImage: true)
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.lg) {
                            // Header with photo
                            headerSection

                            // Status section
                            statusSection

                            // Location section
                            locationSection

                            // Hours & Info
                            infoSection

                            // Actions
                            actionsSection
                        }
                        .padding(Spacing.md)
                    }
                }
            }
            .background(Color.backgroundGradient)
            .navigationTitle(fridge.name)
            .detailNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t.t("common.done")) { dismiss() }
                }
            }
            .task {
                // Initialize displayDescription
                displayDescription = fridge.description ?? ""

                // Brief skeleton display for smooth transition
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(reduceMotion ? .none : .easeOut(duration: 0.2)) {
                    isLoading = false
                }

                // Trigger staggered section entrance animations
                withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                    sectionsAppeared = true
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            // Photo or placeholder with fade transition
            if let photoUrl = fridge.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        FridgeImageShimmer()
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity.animation(.interpolatingSpring(stiffness: 300, damping: 24)))
                    case .failure:
                        fridgePlaceholder
                    @unknown default:
                        fridgePlaceholder
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            } else {
                fridgePlaceholder
            }

            // Name and status
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(fridge.name)
                        .font(.LiquidGlass.headlineLarge)
                        .foregroundColor(.DesignSystem.text)

                    if let host = fridge.hostCompany {
                        Text(t.t("fridge.hosted_by", args: ["host": host]))
                            .font(.LiquidGlass.bodySmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                FridgeStatusBadge(status: fridge.status)
            }
        }
    }

    private var fridgePlaceholder: some View {
        RoundedRectangle(cornerRadius: Spacing.md)
            .fill(Color.DesignSystem.glassBackground)
            .frame(height: 200)
            .overlay(
                Image(systemName: "refrigerator")
                    .font(.system(size: 60))
                    .foregroundColor(.DesignSystem.primary.opacity(0.5)),
            )
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            GlassSectionHeader.info(t.t("fridge.current_status"))

            HStack(spacing: Spacing.md) {
                // Food status
                StatusCard(
                    title: t.t("fridge.food_level"),
                    value: fridge.latestFoodStatus?.capitalized ?? t.t("common.unknown"),
                    icon: "leaf.fill",
                    color: foodStatusColor,
                )

                // Cleanliness
                StatusCard(
                    title: t.t("fridge.cleanliness"),
                    value: fridge.latestCleanlinessStatus?.capitalized ?? t.t("common.unknown"),
                    icon: "sparkles",
                    color: cleanlinessColor,
                )
            }

            // Last updated
            if let lastUpdated = fridge.statusLastUpdated {
                Text(t.t("fridge.last_updated", args: ["time": lastUpdated.formatted(.relative(presentation: .named))]))
                    .font(.LiquidGlass.caption)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
        .detailSection(index: 0, sectionsAppeared: $sectionsAppeared)
    }

    private var foodStatusColor: Color {
        guard let status = fridge.latestFoodStatus?.lowercased() else { return .gray }
        switch status {
        case "nearly empty": return .red
        case "room for more": return .orange
        case "plenty of food": return .green
        case "overflowing": return .blue
        default: return .gray
        }
    }

    private var cleanlinessColor: Color {
        guard let status = fridge.latestCleanlinessStatus?.lowercased() else { return .gray }
        switch status {
        case "clean": return .green
        case "needs cleaning": return .orange
        case "dirty": return .red
        default: return .gray
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            GlassSectionHeader.location(t.t("common.location"))

            // Map preview with address and directions
            #if !SKIP
            if let coordinate = fridge.coordinate {
                // TODO: Replace with standard MapKit view
                Map {
                    Marker(fridge.name, coordinate: coordinate)
                }
                .mapStyle(.standard)
                .frame(height: 200)
                .cornerRadius(CornerRadius.medium)
            }
            #endif

            // Additional directions info
            if let directions = fridge.referenceDirections {
                Text(directions)
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            // Distance pill
            if let distance = fridge.distanceDisplay {
                GlassStatPill.distance(distance)
            }
        }
        .detailSection(index: 1, sectionsAppeared: $sectionsAppeared)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            GlassSectionHeader.details(t.t("common.information"))

            VStack(spacing: Spacing.sm) {
                // Hours
                if let hours = fridge.availableHours {
                    GlassDetailRow(
                        icon: "clock.fill",
                        iconColor: .orange,
                        label: t.t("fridge.info.hours"),
                        value: hours,
                    )
                }

                // Pantry
                GlassDetailRow(
                    icon: "cabinet.fill",
                    iconColor: .DesignSystem.brandGreen,
                    label: t.t("fridges.pantry"),
                    value: fridge.hasPantry ? t.t("common.yes") : t.t("common.no"),
                )

                // Location type
                if let locationType = fridge.locationType {
                    GlassDetailRow(
                        icon: "building.2.fill",
                        iconColor: .DesignSystem.brandBlue,
                        label: t.t("fridge.info.location_type"),
                        value: locationType.capitalized,
                    )
                }

                // Languages
                if let languages = fridge.languages, !languages.isEmpty {
                    GlassDetailRow(
                        icon: "globe",
                        iconColor: .purple,
                        label: t.t("fridge.info.languages"),
                        value: languages.joined(separator: ", "),
                    )
                }

                // Check-ins
                GlassDetailRow(
                    icon: "person.2.fill",
                    iconColor: .DesignSystem.accentBlue,
                    label: t.t("fridge.info.total_check_ins"),
                    value: "\(fridge.totalCheckIns)",
                )

                // Age
                if let ageYears = fridge.ageYears {
                    GlassDetailRow(
                        icon: "calendar",
                        iconColor: .DesignSystem.textSecondary,
                        label: t.t("fridge.info.operating_since"),
                        value: t.t("fridge.years_format", args: ["years": String(format: "%.1f", ageYears)]),
                    )
                }
            }

            // Description with translation support
            if let description = fridge.description {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(t.t("common.about"))
                        .font(.LiquidGlass.labelMedium)
                        .foregroundColor(.DesignSystem.textSecondary)
                    Text(displayDescription.isEmpty ? description : displayDescription)
                        .font(.LiquidGlass.bodyMedium)
                        .foregroundColor(.DesignSystem.text)
                    if isDescriptionTranslated {
                        TranslatedIndicator()
                    }
                }
                .autoTranslate(
                    original: description,
                    contentType: "community_fridge",
                    translated: $displayDescription,
                    isTranslated: $isDescriptionTranslated,
                )
            }
        }
        .detailSection(index: 2, sectionsAppeared: $sectionsAppeared)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            // Check-in button
            if let checkInLink = fridge.checkInLink, let url = URL(string: checkInLink) {
                GlassButton(
                    t.t("fridge.action.check_in"),
                    icon: "checkmark.circle.fill",
                    style: .green,
                ) {
                    openURL(url)
                }
            }

            // Slack channel
            if let slackLink = fridge.slackChannelLink, let url = URL(string: slackLink) {
                GlassButton(
                    t.t("fridge.action.join_slack"),
                    icon: "bubble.left.and.bubble.right.fill",
                    style: .secondary,
                ) {
                    openURL(url)
                }
            }

            // Report Issue button
            GlassButton(
                t.t("fridge.action.report_issue"),
                icon: "exclamationmark.bubble.fill",
                style: .outline,
            ) {
                showReportIssue = true
            }
        }
        .detailSection(index: 3, sectionsAppeared: $sectionsAppeared)
        .confirmationDialog(t.t("fridge.report_an_issue"), isPresented: $showReportIssue, titleVisibility: .visible) {
            ForEach(ReportIssueType.allCases) { issueType in
                Button(localizedIssueType(issueType)) {
                    reportIssueType = issueType
                }
            }
            Button(t.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t.t("fridge.what_type_of_issue"))
        }
        .sheet(item: $reportIssueType) { issueType in
            ReportIssueSheet(fridge: fridge, issueType: issueType)
        }
    }

    // MARK: - Helpers

    private func localizedIssueType(_ issueType: ReportIssueType) -> String {
        switch issueType {
        case .damaged: t.t("fridge.issue.damaged")
        case .cleanlinessIssue: t.t("fridge.issue.cleanliness")
        case .accessProblem: t.t("fridge.issue.access")
        case .safetyHazard: t.t("fridge.issue.safety")
        case .other: t.t("fridge.issue.other")
        }
    }

    #if !SKIP
    private func openMaps(coordinate: CLLocationCoordinate2D) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = fridge.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
        ])
    }
    #endif
}

// MARK: - Status Card

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.LiquidGlass.labelLarge)
                .foregroundColor(.DesignSystem.text)

            Text(title)
                .font(.LiquidGlass.caption)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Report Issue Sheet

struct ReportIssueSheet: View {
    @Environment(\.translationService) private var t
    let fridge: CommunityFridge
    let issueType: CommunityFridgeDetailView.ReportIssueType
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Issue type header
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: issueType.icon)
                                .font(.title2)
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(issueType.rawValue)
                                    .font(.LiquidGlass.headlineMedium)
                                    .foregroundColor(.DesignSystem.text)

                                Text(fridge.name)
                                    .font(.LiquidGlass.bodySmall)
                                    .foregroundColor(.DesignSystem.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(Spacing.md)
                        .glassBackground()

                        // Description field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(t.t("fridge.describe_issue"))
                                .font(.LiquidGlass.labelLarge)
                                .foregroundColor(.DesignSystem.text)

                            TextEditor(text: $description)
                                .frame(minHeight: 150)
                                .foregroundStyle(Color.DesignSystem.text)
                                .scrollContentBackground(.hidden)
                                .padding(Spacing.sm)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1),
                                )

                            Text(t.t("fridge.provide_detail_hint"))
                                .font(.LiquidGlass.caption)
                                .foregroundColor(.DesignSystem.textSecondary)
                        }
                        .padding(Spacing.md)
                        .glassBackground()

                        // Submit button
                        GlassButton(
                            t.t("fridge.submit_report"),
                            icon: "paperplane.fill",
                            style: .primary,
                            isLoading: isSubmitting,
                        ) {
                            submitReport()
                        }
                        .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(t.t("fridge.report_issue"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) { dismiss() }
                }
            }
            .alert(t.t("fridge.report_submitted"), isPresented: $showSuccess) {
                Button(t.t("common.ok")) { dismiss() }
            } message: {
                Text(t.t("fridge.report_thanks_message"))
            }
        }
    }

    private func submitReport() {
        isSubmitting = true
        // Simulate API call
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                isSubmitting = false
                showSuccess = true
            }
        }
    }
}

// MARK: - Fridge Image Shimmer

private struct FridgeImageShimmer: View {
    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        Color.DesignSystem.textTertiary.opacity(0.3),
                        Color.DesignSystem.textTertiary.opacity(0.2),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                )

                // Shimmer overlay
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.15),
                        Color.clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing,
                )
                .frame(width: 150)
                .offset(x: shimmerPhase)
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                    ) {
                        shimmerPhase = geometry.size.width + 150
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        CommunityFridgeDetailView(fridge: .fixture())
    }
#endif
