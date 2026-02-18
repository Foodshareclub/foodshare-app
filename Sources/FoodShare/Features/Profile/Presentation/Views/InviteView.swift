//
//  InviteView.swift
//  Foodshare
//
//  Invite friends to Foodshare via email or share link
//  ProMotion 120Hz optimized with smooth animations
//


#if !SKIP
import SwiftUI



// MARK: - Invite View

/// View for inviting friends to join Foodshare
struct InviteView: View {
    
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss: DismissAction

    // MARK: - State

    @State private var viewModel = InviteViewModel()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroSection
                shareSection
                emailInviteSection

                if viewModel.showResult {
                    resultSection
                }
            }
            .padding()
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("invite.title"))
        .navigationBarTitleDisplayMode(.large)
        .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
            Button(t.t("common.ok")) { viewModel.dismissError() }
        } message: {
            Text(viewModel.localizedErrorMessage(using: t))
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.3),
                                Color.DesignSystem.brandBlue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100.0, height: 100)

                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(t.t("invite.hero.title"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.textPrimary)

            Text(t.t("invite.hero.description"))
                .font(.subheadline)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Share Section

    private var shareSection: some View {
        VStack(spacing: 16) {
            Text(t.t("invite.share.title"))
                .font(.headline)
                .foregroundColor(.DesignSystem.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Text("foodshare.club/invite")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()

                Button {
                    viewModel.copyLink()
                } label: {
                    Image(systemName: viewModel.linkCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.linkCopied ? .DesignSystem.brandGreen : .DesignSystem.brandBlue)
                }
                .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: viewModel.linkCopied)
            }
            .padding()
            .background(glassFieldBackground)

            GlassButton(
                t.t("invite.share.button"),
                icon: "square.and.arrow.up",
                style: .secondary
            ) {
                viewModel.shareLink()
            }
        }
        .padding()
        .background(glassCardBackground)
    }

    // MARK: - Email Invite Section

    private var emailInviteSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(t.t("invite.email.title"))
                    .font(.headline)
                    .foregroundColor(.DesignSystem.textPrimary)

                Spacer()

                Text("\(viewModel.emails.count)/10")
                    .font(.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }

            // Email input
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.DesignSystem.textTertiary)

                TextField(t.t("invite.email.placeholder"), text: $viewModel.currentEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    #if !SKIP
                    .autocapitalization(.none)
                    #endif
                    .autocorrectionDisabled()
                    .onSubmit {
                        viewModel.addEmail()
                    }

                if !viewModel.currentEmail.isEmpty {
                    Button {
                        viewModel.addEmail()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.DesignSystem.brandGreen)
                    }
                }
            }
            .padding()
            .background(glassFieldBackground)

            // Email chips
            if !viewModel.emails.isEmpty {
                #if !SKIP
                InviteFlowLayout(spacing: 8) {
                    ForEach(viewModel.emails, id: \.self) { email in
                        EmailChip(email: email) {
                            viewModel.removeEmail(email)
                        }
                    }
                }
                #else
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                    ForEach(viewModel.emails, id: \.self) { email in
                        EmailChip(email: email) {
                            viewModel.removeEmail(email)
                        }
                    }
                }
                #endif
            }

            GlassButton(
                t.t("invite.email.send_button"),
                icon: "paperplane.fill",
                style: .primary,
                isLoading: viewModel.isLoading
            ) {
                Task { await viewModel.sendInvitations() }
            }
            .disabled(viewModel.emails.isEmpty)
        }
        .padding()
        .background(glassCardBackground)
    }

    // MARK: - Result Section

    private var resultSection: some View {
        VStack(spacing: 16) {
            if let result = viewModel.result {
                if result.allSucceeded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.DesignSystem.brandGreen)

                    Text(t.t("invite.result.success.title"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.textPrimary)

                    Text(t.t("invite.result.success.description", args: ["count": "\(result.successCount)"]))
                        .font(.subheadline)
                        .foregroundColor(.DesignSystem.textSecondary)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text(t.t("invite.result.partial.title"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.textPrimary)

                    Text(t.t("invite.result.partial.description", args: ["sent": "\(result.successCount)", "failed": "\(result.failedEmails.count)"]))
                        .font(.subheadline)
                        .foregroundColor(.DesignSystem.textSecondary)

                    if !result.failedEmails.isEmpty {
                        Text(t.t("invite.result.failed", args: ["emails": result.failedEmails.joined(separator: ", ")]))
                            .font(.caption)
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                }
            }
        }
        .padding()
        .background(glassCardBackground)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: viewModel.showResult)
    }

    // MARK: - Helpers

    private var glassFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Email Chip

private struct EmailChip: View {
    let email: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(email)
                .font(.caption)
                .foregroundColor(.DesignSystem.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.DesignSystem.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

#if !SKIP
// MARK: - Invite Flow Layout

private struct InviteFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x - spacing)
            }

            self.size.height = y + rowHeight
        }
    }
}
#endif

// MARK: - ViewModel

@MainActor
@Observable
final class InviteViewModel {
    var currentEmail = ""
    var emails: [String] = []
    var isLoading = false
    var linkCopied = false
    var result: InvitationResult?
    var showResult = false
    var error: Error?
    var showError = false

    var errorMessage: String {
        error?.localizedDescription ?? "An error occurred"
    }

    /// Localized error message (use in Views with translation service)
    func localizedErrorMessage(using t: EnhancedTranslationService) -> String {
        error?.localizedDescription ?? t.t("invite.load_failed")
    }

    func addEmail() {
        let email = currentEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, isValidEmail(email), !emails.contains(email), emails.count < 10 else {
            return
        }

        emails.append(email)
        currentEmail = ""
        HapticManager.light()
    }

    func removeEmail(_ email: String) {
        emails.removeAll { $0 == email }
        HapticManager.light()
    }

    func copyLink() {
        UIPasteboard.general.string = "https://foodshare.club/invite"
        linkCopied = true
        HapticManager.success()

        Task {
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000))
            #else
            try? await Task.sleep(for: .seconds(2))
            #endif
            linkCopied = false
        }
    }

    func shareLink() {
        InvitationService.shared.shareInviteLink()
    }

    func sendInvitations() async {
        guard !emails.isEmpty else { return }
        isLoading = true
        showResult = false

        do {
            result = try await InvitationService.shared.sendInvitations(emails: emails)
            showResult = true

            if result?.allSucceeded == true {
                emails.removeAll()
            } else if let failed = result?.failedEmails {
                emails = failed
            }
        } catch {
            self.error = error
            showError = true
        }

        isLoading = false
    }

    func dismissError() {
        showError = false
        error = nil
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

#Preview {
    NavigationStack {
        InviteView()
    }
}

#endif
