//
//  GlassActionSheet.swift
//  Foodshare
//
//  Liquid Glass v27 Action Sheet with ProMotion 120Hz animations
//  Premium iOS action sheet replacement with staggered animations,
//  haptic feedback, and full glassmorphism styling
//


#if !SKIP
import SwiftUI

// MARK: - Glass Action Sheet

/// A premium action sheet with Liquid Glass styling and ProMotion animations
/// Replaces standard iOS action sheets with a consistent glass aesthetic
struct GlassActionSheet: View {
    @Binding var isPresented: Bool
    let title: String?
    let message: String?
    let actions: [GlassActionItem]
    let cancelAction: GlassActionItem?

    @State private var offset: CGFloat = 500
    @State private var backgroundOpacity: Double = 0
    @State private var actionStates: [Bool] = []

    init(
        isPresented: Binding<Bool>,
        title: String? = nil,
        message: String? = nil,
        actions: [GlassActionItem],
        cancelAction: GlassActionItem? = nil
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.actions = actions
        self.cancelAction = cancelAction ?? GlassActionItem(title: "Cancel", style: .cancel, action: {})
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Sheet content
            VStack(spacing: Spacing.sm) {
                // Actions group
                actionsCard

                // Cancel button (separate card)
                if let cancel = cancelAction {
                    cancelButton(cancel)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.lg)
            .offset(y: offset)
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                present()
            } else {
                dismiss()
            }
        }
        .onAppear {
            if isPresented {
                present()
            }
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 0) {
            // Header (title + message)
            if title != nil || message != nil {
                headerSection
                GlassDivider()
            }

            // Action items
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                VStack(spacing: 0) {
                    actionButton(action, at: index)

                    if index < actions.count - 1 {
                        GlassDivider()
                    }
                }
            }
        }
        .background(sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.glassHighlight,
                            Color.DesignSystem.glassBorder,
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 30, y: 10)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.xs) {
            if let title = title {
                Text(title)
                    .font(.DesignSystem.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)
                    .multilineTextAlignment(.center)
            }

            if let message = message {
                Text(message)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Action Button

    private func actionButton(_ action: GlassActionItem, at index: Int) -> some View {
        Button {
            HapticManager.medium()
            action.action()
            dismiss()
        } label: {
            HStack(spacing: Spacing.sm) {
                if let icon = action.icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 24.0)
                }

                Text(action.title)
                    .font(.DesignSystem.bodyLarge)
                    .fontWeight(action.style == .destructive ? .semibold : .regular)
            }
            .foregroundColor(action.style.color)
            .frame(maxWidth: .infinity)
            .frame(height: 56.0)
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(ActionSheetButtonStyle())
        .disabled(action.isDisabled)
        .opacity(action.isDisabled ? 0.5 : 1.0)
        .opacity(actionStates.indices.contains(index) && actionStates[index] ? 1 : 0)
        .offset(y: actionStates.indices.contains(index) && actionStates[index] ? 0 : 20)
    }

    // MARK: - Cancel Button

    private func cancelButton(_ action: GlassActionItem) -> some View {
        Button {
            HapticManager.light()
            action.action()
            dismiss()
        } label: {
            Text(action.title)
                .font(.DesignSystem.bodyLarge)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.brandPink)
                .frame(maxWidth: .infinity)
                .frame(height: 56.0)
        }
        .buttonStyle(ActionSheetButtonStyle())
        .background(sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, y: 5)
    }

    // MARK: - Sheet Background

    private var sheetBackground: some View {
        ZStack {
            Rectangle()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            // Top highlight
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Presentation

    private func present() {
        // Initialize action states
        actionStates = Array(repeating: false, count: actions.count)

        // Animate in with ProMotion 120Hz optimized spring
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 28)) {
            offset = 0
            backgroundOpacity = 0.4
        }

        // Stagger action button animations
        Task { @MainActor in
            for index in actions.indices {
                let delay = UInt64((50 + Double(index) * 30))
                #if SKIP
                try? await Task.sleep(nanoseconds: delay * 1_000_000)
                #else
                try? await Task.sleep(for: .milliseconds(delay))
                #endif
                withAnimation(.interpolatingSpring(stiffness: 350, damping: 25)) {
                    if actionStates.indices.contains(index) {
                        actionStates[index] = true
                    }
                }
            }
        }

        HapticManager.medium()
    }

    private func dismiss() {
        // Animate out
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 30)) {
            offset = 500
            backgroundOpacity = 0
        }

        // Dismiss after animation
        Task { @MainActor in
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(250 * 1_000_000))
            #else
            try? await Task.sleep(for: .milliseconds(250))
            #endif
            isPresented = false
        }
    }
}

// MARK: - Glass Action Item

/// A single action item for the Glass Action Sheet
struct GlassActionItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let style: ActionStyle
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        style: ActionStyle = .default,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }

    enum ActionStyle {
        case `default`
        case destructive
        case cancel

        var color: Color {
            switch self {
            case .default:
                Color.DesignSystem.text
            case .destructive:
                Color.DesignSystem.error
            case .cancel:
                Color.DesignSystem.brandPink
            }
        }
    }
}

// MARK: - Action Sheet Button Style

private struct ActionSheetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.DesignSystem.glassBackground.opacity(0.5)
                    : Color.clear
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Animation.interpolatingSpring(stiffness: 400, damping: 25), value: configuration.isPressed)
    }
}

// MARK: - View Extension

extension View {
    /// Present a Liquid Glass action sheet
    func glassActionSheet(
        isPresented: Binding<Bool>,
        title: String? = nil,
        message: String? = nil,
        actions: [GlassActionItem],
        cancelAction: GlassActionItem? = nil
    ) -> some View {
        ZStack {
            self

            if isPresented.wrappedValue {
                GlassActionSheet(
                    isPresented: isPresented,
                    title: title,
                    message: message,
                    actions: actions,
                    cancelAction: cancelAction
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented.wrappedValue)
    }
}

// MARK: - Confirmation Dialog Wrapper

/// Convenience wrapper for common confirmation dialogs
struct GlassConfirmationDialog {
    /// Creates a delete confirmation action sheet
    static func delete(
        title: String = "Delete Item",
        message: String = "Are you sure you want to delete this item? This action cannot be undone.",
        onDelete: @escaping () -> Void
    ) -> (title: String?, message: String?, actions: [GlassActionItem]) {
        (
            title: title,
            message: message,
            actions: [
                GlassActionItem(
                    title: "Delete",
                    icon: "trash.fill",
                    style: .destructive,
                    action: onDelete
                )
            ]
        )
    }

    /// Creates a share options action sheet
    static func share(
        onCopyLink: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onReport: @escaping () -> Void
    ) -> [GlassActionItem] {
        [
            GlassActionItem(title: "Copy Link", icon: "link", action: onCopyLink),
            GlassActionItem(title: "Share", icon: "square.and.arrow.up", action: onShare),
            GlassActionItem(title: "Report", icon: "flag", style: .destructive, action: onReport)
        ]
    }

    /// Creates listing actions for food items
    static func listingActions(
        onEdit: @escaping () -> Void,
        onMarkClaimed: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> [GlassActionItem] {
        [
            GlassActionItem(title: "Edit Listing", icon: "pencil", action: onEdit),
            GlassActionItem(title: "Mark as Claimed", icon: "checkmark.circle", action: onMarkClaimed),
            GlassActionItem(title: "Share", icon: "square.and.arrow.up", action: onShare),
            GlassActionItem(title: "Delete", icon: "trash", style: .destructive, action: onDelete)
        ]
    }
}

// MARK: - Preview

#Preview("Basic Action Sheet") {
    @Previewable @State var showSheet = true

    ZStack {
        LinearGradient(
            colors: [
                Color.DesignSystem.brandPink.opacity(0.15),
                Color.DesignSystem.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            GlassButton("Show Actions", style: .primary) {
                showSheet = true
            }
        }
    }
    .glassActionSheet(
        isPresented: $showSheet,
        title: "What would you like to do?",
        message: "Choose an action for this item",
        actions: [
            GlassActionItem(title: "Edit", icon: "pencil") { print("Edit") },
            GlassActionItem(title: "Share", icon: "square.and.arrow.up") { print("Share") },
            GlassActionItem(title: "Delete", icon: "trash", style: .destructive) { print("Delete") }
        ]
    )
}

#Preview("Listing Actions") {
    @Previewable @State var showSheet = true

    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        VStack {
            Text("Tap to show actions")
                .foregroundColor(.DesignSystem.textSecondary)
        }
    }
    .glassActionSheet(
        isPresented: $showSheet,
        title: "Listing Options",
        actions: GlassConfirmationDialog.listingActions(
            onEdit: { print("Edit") },
            onMarkClaimed: { print("Claimed") },
            onShare: { print("Share") },
            onDelete: { print("Delete") }
        )
    )
}

#endif
