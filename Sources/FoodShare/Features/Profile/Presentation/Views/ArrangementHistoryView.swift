//
//  ArrangementHistoryView.swift
//  Foodshare
//
//  Refactored with Swift 6 bleeding-edge practices:
//  - Extracted ViewModel for state management
//  - Type-safe enums for filters and date ranges
//  - Composable view architecture
//  - Efficient data filtering with extensions
//


#if !SKIP
import SwiftUI

// MARK: - Localized Display Names Extension

extension ArrangementFilter {
    @MainActor
    func displayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .all: t.t("profile.history.filter.all")
        case .shared: t.t("profile.history.filter.shared")
        case .received: t.t("profile.history.filter.received")
        }
    }
}

extension DateRange {
    @MainActor
    func displayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .all: t.t("profile.history.date_range.all_time")
        case .week: t.t("profile.history.date_range.this_week")
        case .month: t.t("profile.history.date_range.this_month")
        case .quarter: t.t("profile.history.date_range.last_3_months")
        case .year: t.t("profile.history.date_range.this_year")
        case .custom: t.t("profile.history.date_range.custom")
        }
    }
}

// MARK: - Arrangement History ViewModel

@MainActor
@Observable
final class ArrangementHistoryViewModel {
    // MARK: - State

    private(set) var history: [ArrangementRecord] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    var selectedFilter: ArrangementFilter = .all
    var selectedDateRange: DateRange = .all
    var searchText = ""
    var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var customEndDate = Date()

    // MARK: - Computed Properties

    var filteredHistory: [ArrangementRecord] {
        history
            .filtered(by: selectedDateRange, customStart: customStartDate, customEnd: customEndDate)
            .filtered(bySearch: searchText)
            .filtered(by: selectedFilter)
            .sorted { $0.arrangedAt > $1.arrangedAt }
    }

    var sharedCount: Int { filteredHistory.filter(\.isSharer).count }
    var receivedCount: Int { filteredHistory.count(where: { !$0.isSharer }) }

    func count(for filter: ArrangementFilter) -> Int {
        let dateFiltered = history.filtered(
            by: selectedDateRange,
            customStart: customStartDate,
            customEnd: customEndDate,
        )
        switch filter {
        case .all: return dateFiltered.count
        case .shared: return dateFiltered.filter(\.isSharer).count
        case .received: return dateFiltered.count(where: { !$0.isSharer })
        }
    }

    // MARK: - Dependencies

    private let userId: UUID
    private let repository: ListingRepository

    init(userId: UUID, repository: ListingRepository) {
        self.userId = userId
        self.repository = repository
    }

    // MARK: - Actions

    func loadHistory() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            history = try await repository.fetchArrangementHistory(userId: userId)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .networkError(error.localizedDescription)
        }
    }

    func refresh() async {
        do {
            history = try await repository.fetchArrangementHistory(userId: userId)
            HapticManager.light()
        } catch {
            // Keep existing data on refresh failure
        }
    }

    func generateSummary() -> String {
        let completed = filteredHistory.filter { $0.status == .completed }
        let shared = completed.filter(\.isSharer).count
        let received = completed.count(where: { !$0.isSharer })

        var summary = """
        🍽️ Foodshare Activity Summary
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        📊 Overview
        • Total Arrangements: \(completed.count)
        • Items Shared: \(shared)
        • Items Received: \(received)

        """

        if selectedDateRange != .all {
            summary += "📅 Period: \(selectedDateRange.rawValue)\n\n"
        }

        let recent = Array(filteredHistory.prefix(5))
        if !recent.isEmpty {
            summary += "📋 Recent Activity\n"
            for record in recent {
                let action = record.isSharer ? "Shared" : "Received"
                let date = record.arrangedAt.formatted(date: .abbreviated, time: .omitted)
                summary += "• \(action): \(record.postName) (\(date))\n"
            }
        }

        summary += "\n🌱 Thank you for reducing food waste!"
        return summary
    }
}

// MARK: - Supporting Types

enum ArrangementFilter: String, CaseIterable {
    case all = "All"
    case shared = "Shared"
    case received = "Received"

    var icon: String {
        switch self {
        case .all: "list.bullet"
        case .shared: "arrow.up.circle.fill"
        case .received: "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: .DesignSystem.brandGreen
        case .shared: .orange
        case .received: .DesignSystem.success
        }
    }
}

enum DateRange: String, CaseIterable {
    case all = "All Time"
    case week = "This Week"
    case month = "This Month"
    case quarter = "Last 3 Months"
    case year = "This Year"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .all: "infinity"
        case .week: "calendar.badge.clock"
        case .month: "calendar"
        case .quarter: "calendar.badge.plus"
        case .year: "calendar.circle"
        case .custom: "calendar.badge.exclamationmark"
        }
    }

    func dateRange() -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .all, .custom: return nil
        case .week: return (calendar.date(byAdding: .day, value: -7, to: now) ?? now, now)
        case .month: return (calendar.date(byAdding: .month, value: -1, to: now) ?? now, now)
        case .quarter: return (calendar.date(byAdding: .month, value: -3, to: now) ?? now, now)
        case .year: return (calendar.date(byAdding: .year, value: -1, to: now) ?? now, now)
        }
    }
}

// MARK: - Array Extensions

extension [ArrangementRecord] {
    fileprivate func filtered(by dateRange: DateRange, customStart: Date, customEnd: Date) -> [ArrangementRecord] {
        if dateRange == .custom {
            return filter { $0.arrangedAt >= customStart && $0.arrangedAt <= customEnd }
        } else if let range = dateRange.dateRange() {
            return filter { $0.arrangedAt >= range.start && $0.arrangedAt <= range.end }
        }
        return self
    }

    fileprivate func filtered(bySearch query: String) -> [ArrangementRecord] {
        guard !query.isEmpty else { return self }
        let lowercased = query.lowercased()
        return filter {
            $0.postName.lowercased().contains(lowercased) || $0.otherUserName.lowercased().contains(lowercased)
        }
    }

    fileprivate func filtered(by filter: ArrangementFilter) -> [ArrangementRecord] {
        switch filter {
        case .all: self
        case .shared: self.filter(\.isSharer)
        case .received: self.filter { !$0.isSharer }
        }
    }
}

// MARK: - Arrangement History View

struct ArrangementHistoryView: View {
    @Environment(\.translationService) private var t
    let userId: UUID
    let repository: ListingRepository

    @State private var viewModel: ArrangementHistoryViewModel
    @State private var showDatePicker = false
    @State private var selectedRecord: ArrangementRecord?

    init(userId: UUID, repository: ListingRepository) {
        self.userId = userId
        self.repository = repository
        _viewModel = State(initialValue: ArrangementHistoryViewModel(userId: userId, repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.history.isEmpty, !viewModel.isLoading {
                HistoryStatsSummary(history: viewModel.filteredHistory)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
            }

            HistorySearchBar(searchText: $viewModel.searchText)
            DateRangeSelector(viewModel: viewModel, showDatePicker: $showDatePicker)
            HistoryFilterSelector(viewModel: viewModel)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

            HistoryContent(viewModel: viewModel, selectedRecord: $selectedRecord)
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("profile.history.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { historyToolbar }
        .task { await viewModel.loadHistory() }
        .refreshable { await viewModel.refresh() }
        .sheet(isPresented: $showDatePicker) {
            CustomDateRangePicker(
                startDate: $viewModel.customStartDate,
                endDate: $viewModel.customEndDate,
                onApply: {
                    showDatePicker = false
                    HapticManager.success()
                },
            )
            .presentationDetents([PresentationDetent.medium])
        }
        .sheet(item: $selectedRecord) { record in
            ArrangementDetailSheet(record: record)
                .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
        }
    }

    @ToolbarContentBuilder
    private var historyToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Section(t.t("profile.history.export")) {
                    Button {
                        exportHistory()
                    } label: {
                        Label(t.t("profile.history.share_summary"), systemImage: "square.and.arrow.up")
                    }
                }

                Section(t.t("profile.history.date_range._title")) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedDateRange = range
                                if range == .custom { showDatePicker = true }
                            }
                            HapticManager.selection()
                        } label: {
                            Label(
                                range.displayName(using: t),
                                systemImage: viewModel.selectedDateRange == range ? "checkmark" : range.icon,
                            )
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.DesignSystem.text)
            }
        }
    }

    private func exportHistory() {
        let summary = viewModel.generateSummary()
        #if !SKIP
        let activityVC = UIActivityViewController(activityItems: [summary], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
        HapticManager.success()
    }
}

// MARK: - History Search Bar

private struct HistorySearchBar: View {
    @Environment(\.translationService) private var t
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .font(.system(size: 16))

            TextField(t.t("profile.history.search"), text: $searchText)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.text)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticManager.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(
                    Color.DesignSystem.glassBorder,
                    lineWidth: 1,
                )),
        )
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Date Range Selector

private struct DateRangeSelector: View {
    @Environment(\.translationService) private var t
    @Bindable var viewModel: ArrangementHistoryViewModel
    @Binding var showDatePicker: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(DateRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                    DateRangeChip(
                        title: range.displayName(using: t),
                        icon: range.icon,
                        isSelected: viewModel.selectedDateRange == range,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) { viewModel.selectedDateRange = range }
                            HapticManager.selection()
                        },
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        #if !SKIP
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        #endif
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Date Range Chip

struct DateRangeChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                Text(title)
                    .font(.DesignSystem.labelSmall)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? .white : Color.DesignSystem.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(isSelected ? Color.DesignSystem.brandGreen : Color.DesignSystem.glassBackground))
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.DesignSystem.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(isSelected ? "selected" : "not selected")")
    }
}

// MARK: - History Filter Selector

private struct HistoryFilterSelector: View {
    @Environment(\.translationService) private var t
    @Bindable var viewModel: ArrangementHistoryViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ArrangementFilter.allCases, id: \.self) { filter in
                filterButton(filter)
            }
        }
        .padding(Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(
                    Color.DesignSystem.glassBorder,
                    lineWidth: 1,
                )),
        )
    }

    private func filterButton(_ filter: ArrangementFilter) -> some View {
        let isSelected = viewModel.selectedFilter == filter
        let count = viewModel.count(for: filter)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.selectedFilter = filter }
            HapticManager.selection()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? filter.color : Color.DesignSystem.textSecondary)

                Text(filter.displayName(using: t))
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.DesignSystem.captionSmall)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? .white : Color.DesignSystem.textSecondary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected
                                ? Color.DesignSystem.brandGreen
                                : Color.DesignSystem.glassBackground))
                }
            }
            .foregroundStyle(isSelected ? Color.DesignSystem.text : Color.DesignSystem.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(isSelected
                    ? Color.DesignSystem.glassHighlight
                    : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.displayName(using: t)), \(count) \(t.t("common.items"))")
    }
}

// MARK: - History Content

private struct HistoryContent: View {
    let viewModel: ArrangementHistoryViewModel
    @Binding var selectedRecord: ArrangementRecord?

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.history.isEmpty {
                HistoryLoadingView()
            } else if let error = viewModel.error, viewModel.history.isEmpty {
                HistoryErrorView(error: error) {
                    Task { await viewModel.loadHistory() }
                }
            } else if viewModel.filteredHistory.isEmpty {
                HistoryEmptyView(filter: viewModel.selectedFilter)
            } else {
                HistoryListView(history: viewModel.filteredHistory, selectedRecord: $selectedRecord)
            }
        }
    }
}

// MARK: - History List View

private struct HistoryListView: View {
    let history: [ArrangementRecord]
    @Binding var selectedRecord: ArrangementRecord?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(history) { record in
                    Button {
                        selectedRecord = record
                        HapticManager.light()
                    } label: {
                        ArrangementHistoryCard(record: record)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(Spacing.md)
        }
    }
}

// MARK: - History Stats Summary

private struct HistoryStatsSummary: View {
    @Environment(\.translationService) private var t
    let history: [ArrangementRecord]

    private var sharedCount: Int { history.filter(\.isSharer).count }
    private var receivedCount: Int { history.count(where: { !$0.isSharer }) }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            StatItem(title: t.t("profile.history.stats.total"), value: "\(history.count)", icon: "list.bullet")
            StatItem(title: t.t("profile.history.filter.shared"), value: "\(sharedCount)", icon: "arrow.up.circle")
            StatItem(title: t.t("profile.history.filter.received"), value: "\(receivedCount)", icon: "arrow.down.circle")
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.glassBackground),
        )
    }

    private struct StatItem: View {
        let title: String
        let value: String
        let icon: String

        var body: some View {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.DesignSystem.primary)
                Text(value)
                    .font(.DesignSystem.headlineMedium)
                Text(title)
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Custom Date Range Picker

private struct CustomDateRangePicker: View {
    @Environment(\.translationService) private var t
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                DatePicker(t.t("profile.history.start_date"), selection: $startDate, displayedComponents: .date)
                DatePicker(t.t("profile.history.end_date"), selection: $endDate, displayedComponents: .date)

                GlassButton(t.t("common.apply"), icon: "checkmark", style: .primary) {
                    onApply()
                }
            }
            .padding()
            .navigationTitle(t.t("profile.history.select_date_range"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Arrangement Detail Sheet

private struct ArrangementDetailSheet: View {
    @Environment(\.translationService) private var t
    let record: ArrangementRecord

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(record.postName)
                        .font(.DesignSystem.headlineLarge)

                    Divider()

                    DetailRow(label: t.t("profile.history.detail.type"), value: record.isSharer ? t.t("profile.history.filter.shared") : t.t("profile.history.filter.received"))
                    DetailRow(label: t.t("profile.history.detail.date"), value: record.arrangedAt.formatted(date: .long, time: .shortened))
                    DetailRow(label: t.t("profile.history.detail.with"), value: record.otherUserName)
                    DetailRow(label: t.t("profile.history.detail.status"), value: record.status.rawValue.capitalized)

                    if let completedAt = record.completedAt {
                        DetailRow(label: t.t("profile.history.detail.completed"), value: completedAt.formatted(date: .long, time: .shortened))
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle(t.t("profile.history.details"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private struct DetailRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text("\(label):")
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                Spacer()
                Text(value)
            }
            .font(.DesignSystem.bodyMedium)
        }
    }
}

// MARK: - History Loading View

private struct HistoryLoadingView: View {
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text(t.t("profile.history.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - History Error View

private struct HistoryErrorView: View {
    @Environment(\.translationService) private var t
    let error: Error
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.DesignSystem.warning)

            Text(t.t("profile.history.error.title"))
                .font(.DesignSystem.headlineMedium)

            Text(error.localizedDescription)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            GlassButton(t.t("common.retry"), icon: "arrow.clockwise", style: .primary) {
                onRetry()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - History Empty View

private struct HistoryEmptyView: View {
    @Environment(\.translationService) private var t
    let filter: ArrangementFilter

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(Color.DesignSystem.textTertiary)

            Text(t.t("profile.history.empty.title"))
                .font(.DesignSystem.headlineMedium)

            Text(emptyMessage)
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyMessage: String {
        switch filter {
        case .all: t.t("profile.history.empty.all")
        case .shared: t.t("profile.history.empty.shared")
        case .received: t.t("profile.history.empty.received")
        }
    }
}

// MARK: - Arrangement History Card

private struct ArrangementHistoryCard: View {
    @Environment(\.translationService) private var t
    let record: ArrangementRecord

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Type indicator
            Circle()
                .fill(record.isSharer ? Color.DesignSystem.brandGreen : Color.DesignSystem.primary)
                .frame(width: 40.0, height: 40)
                .overlay(
                    Image(systemName: record.isSharer ? "arrow.up" : "arrow.down")
                        .foregroundStyle(.white),
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(record.postName)
                    .font(.DesignSystem.bodyMedium)
                    .lineLimit(1)

                Text(record.arrangedAt, style: .date)
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Color.DesignSystem.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.glassBackground),
        )
        #if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.isSharer ? t.t("profile.history.filter.shared") : t.t("profile.history.filter.received")) \(record.postName)")
        .accessibilityHint(t.t("profile.history.tap_for_details"))
        #endif
    }
}

#endif
