//
//  ArrangementView.swift
//  Foodshare
//
//  View for managing post arrangements
//


#if !SKIP
import SwiftUI



struct ArrangementView: View {
    
    @Environment(\.translationService) private var t

    let post: FoodItem
    let currentUserId: UUID
    let onArrange: () async -> Void
    let onCancel: () async -> Void
    let onComplete: () async -> Void

    @State private var isProcessing = false
    @State private var showConfirmation = false
    @State private var confirmationAction: ConfirmationAction?

    enum ConfirmationAction {
        case arrange, cancel, complete
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            statusSection
            actionButtons
        }
        .padding(Spacing.md)
        .glassBackground()
        .confirmationDialog(
            confirmationTitle,
            isPresented: $showConfirmation,
            titleVisibility: .visible,
        ) {
            Button(confirmationButtonTitle, role: confirmationRole) {
                Task { await performAction() }
            }
            Button(t.t("common.cancel"), role: .cancel) {}
        }
    }

    private var statusSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(statusTitle)
                    .font(.LiquidGlass.labelLarge)
                    .foregroundColor(.DesignSystem.text)
                Text(statusSubtitle)
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusTitle: String {
        if !post.isActive { t.t("arrangement.status.completed") } else if post.isArranged { t.t("arrangement.status.arranged") } else { t.t("arrangement.status.available") }
    }

    private var statusSubtitle: String {
        if !post.isActive { t.t("arrangement.subtitle.shared") } else if post.isArranged {
            if isOwner { t.t("arrangement.subtitle.someone_picking_up") } else if isRequester { t.t("arrangement.subtitle.you_picking_up") } else { t.t("arrangement.subtitle.being_picked_up") }
        } else { t.t("arrangement.subtitle.ready") }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
            Text(statusTitle)
        }
        .font(.LiquidGlass.caption)
        .foregroundColor(statusColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .clipShape(Capsule())
    }

    private var statusIcon: String {
        if !post.isActive { "checkmark.circle.fill" } else if post.isArranged { "clock.fill" } else { "hand.raised.fill" }
    }

    private var statusColor: Color {
        if !post.isActive { .gray } else if post.isArranged { .orange } else { .green }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isProcessing {
            ProgressView().frame(maxWidth: .infinity)
        } else if !post.isActive {
            EmptyView()
        } else if post.isArranged {
            if isOwner || isRequester {
                HStack(spacing: Spacing.sm) {
                    Button {
                        confirmationAction = .cancel
                        showConfirmation = true
                    } label: {
                        Text(t.t("common.cancel")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        confirmationAction = .complete
                        showConfirmation = true
                    } label: {
                        Text(t.t("common.complete")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else if !isOwner {
            GlassButton(
                t.t("arrangement.request_pickup"),
                icon: "hand.raised.fill",
                style: .green
            ) {
                confirmationAction = .arrange
                showConfirmation = true
            }
        }
    }

    private var isOwner: Bool { post.profileId == currentUserId }
    private var isRequester: Bool { post.postArrangedTo == currentUserId }

    private var confirmationTitle: String {
        switch confirmationAction {
        case .arrange: t.t("arrangement.confirm.request_title")
        case .cancel: t.t("arrangement.confirm.cancel_title")
        case .complete: t.t("arrangement.confirm.complete_title")
        case nil: ""
        }
    }

    private var confirmationButtonTitle: String {
        switch confirmationAction {
        case .arrange: t.t("arrangement.confirm.request_button")
        case .cancel: t.t("arrangement.confirm.cancel_button")
        case .complete: t.t("common.complete")
        case nil: ""
        }
    }

    private var confirmationRole: ButtonRole? {
        confirmationAction == .cancel ? .destructive : nil
    }

    private func performAction() async {
        isProcessing = true
        defer { isProcessing = false }
        switch confirmationAction {
        case .arrange: await onArrange()
        case .cancel: await onCancel()
        case .complete: await onComplete()
        case nil: break
        }
    }
}

#endif
