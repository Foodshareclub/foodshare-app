

#if !SKIP
import SwiftUI

#if DEBUG
    import Inject
#endif

// MARK: - Admin Users View

struct AdminUsersView: View {
    
    @Environment(\.translationService) private var t
    @Bindable var viewModel: AdminViewModel
    @State private var searchText = ""
    @State private var showUserDetail = false
    @State private var showBanConfirmation = false
    @State private var banReason = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(t.t("admin.search_users"), text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task { await viewModel.searchUsers(query: searchText) }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task { await viewModel.loadUsers() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.08))

            // Users list
            if viewModel.isLoadingUsers, viewModel.users.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.users.isEmpty {
                Spacer()
                ContentUnavailableView(
                    t.t("admin.no_users_found"),
                    systemImage: "person.slash",
                    description: Text(t.t("admin.try_adjusting_search"))
                )
                Spacer()
            } else {
                List {
                    ForEach(viewModel.users) { user in
                        AdminUserRow(user: user) {
                            Task {
                                await viewModel.selectUser(user)
                                showUserDetail = true
                            }
                        }
                        .listRowBackground(Color.clear)
                        .onAppear {
                            if user.id == viewModel.users.last?.id {
                                Task { await viewModel.loadMoreUsers() }
                            }
                        }
                    }

                    if viewModel.isLoadingMoreUsers {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task {
            await viewModel.loadUsers()
        }
        .sheet(isPresented: $showUserDetail) {
            if let user = viewModel.selectedUser {
                AdminUserDetailSheet(
                    user: user,
                    roles: viewModel.roles,
                    userRoles: viewModel.userRoles,
                    onBan: { reason in
                        Task { await viewModel.banUser(user, reason: reason) }
                    },
                    onUnban: {
                        Task { await viewModel.unbanUser(user) }
                    },
                    onAssignRole: { roleId in
                        Task { await viewModel.assignRole(to: user, roleId: roleId) }
                    },
                    onRevokeRole: { roleId in
                        Task { await viewModel.revokeRole(from: user, roleId: roleId) }
                    },
                )
            }
        }
    }
}

// MARK: - Admin User Row

struct AdminUserRow: View {
    @Environment(\.translationService) private var t
    let user: AdminUserProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: user.avatarURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.1))
                }
                .frame(width: 44.0, height: 44)
                .clipShape(Circle())

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.headline)

                        if user.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }

                        if user.isActive == false {
                            Text(t.t("admin.banned"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.red))
                        }
                    }

                    if let email = user.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        let role = user.primaryRole ?? "member"
                        Text(role.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleColor(role).opacity(0.2))
                            .clipShape(Capsule())

                        if let lastSeen = user.lastSeenAt {
                            Text("\(t.t("admin.last_seen")): \(lastSeen, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "super_admin": .red
        case "admin": .orange
        case "moderator": .purple
        default: .gray
        }
    }
}

// MARK: - Admin User Detail Sheet

struct AdminUserDetailSheet: View {
    @Environment(\.translationService) private var t
    let user: AdminUserProfile
    let roles: [Role]
    let userRoles: [UserRole]
    let onBan: (String) -> Void
    let onUnban: () -> Void
    let onAssignRole: (Int) -> Void
    let onRevokeRole: (Int) -> Void

    @State private var showBanDialog = false
    @State private var banReason = ""
    @State private var showRoleAssignment = false

    @Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack(spacing: 12) {
                        AsyncImage(url: user.avatarURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 80.0, height: 80)
                        .clipShape(Circle())

                        Text(user.displayName)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let email = user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            if user.isVerified == true {
                                Label(t.t("admin.verified"), systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }

                            if user.isActive == false {
                                Label(t.t("admin.banned"), systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(glassBackground)

                    // User info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(t.t("admin.account_info"))
                            .font(.headline)

                        InfoRow(label: t.t("admin.user_id"), value: user.id.uuidString.prefix(8) + "...")

                        if let createdTime = user.createdTime {
                            InfoRow(label: t.t("admin.joined"), value: createdTime.formatted(date: .abbreviated, time: .omitted))
                        }

                        if let lastSeen = user.lastSeenAt {
                            InfoRow(
                                label: t.t("admin.last_active"),
                                value: lastSeen.formatted(date: .abbreviated, time: .shortened)
                            )
                        }

                        InfoRow(label: t.t("admin.role"), value: user.roleNames)
                    }
                    .padding()
                    .background(glassBackground)

                    // Assigned roles
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(t.t("admin.assigned_roles"))
                                .font(.headline)

                            Spacer()

                            Button {
                                showRoleAssignment = true
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }

                        if userRoles.isEmpty {
                            Text(t.t("admin.no_roles"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(userRoles) { userRole in
                                HStack {
                                    Text(userRole.role?.name ?? "Unknown")
                                        .font(.subheadline)

                                    Spacer()

                                    Button {
                                        onRevokeRole(userRole.roleId)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(glassBackground)

                    // Actions
                    VStack(spacing: 12) {
                        if user.isActive == false {
                            Button {
                                onUnban()
                                dismiss()
                            } label: {
                                Label(t.t("admin.unban_user"), systemImage: "person.crop.circle.badge.checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        } else {
                            Button {
                                showBanDialog = true
                            } label: {
                                Label(t.t("admin.ban_user"), systemImage: "person.crop.circle.badge.xmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle(t.t("admin.user_details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) { dismiss() }
                }
            }
        }
        .alert(t.t("admin.ban_user"), isPresented: $showBanDialog) {
            TextField(t.t("admin.ban_reason_placeholder"), text: $banReason)
            Button(t.t("common.cancel"), role: .cancel) {}
            Button(t.t("admin.ban_action"), role: .destructive) {
                onBan(banReason)
                dismiss()
            }
        } message: {
            Text(t.t("admin.ban_confirmation_message"))
        }
        .sheet(isPresented: $showRoleAssignment) {
            RoleAssignmentSheet(
                roles: roles,
                existingRoleIds: Set(userRoles.map(\.roleId)),
                onAssign: { roleId in
                    onAssignRole(roleId)
                },
            )
        }
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1),
            )
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Role Assignment Sheet

struct RoleAssignmentSheet: View {
    @Environment(\.translationService) private var t
    let roles: [Role]
    let existingRoleIds: Set<Int>
    let onAssign: (Int) -> Void

    @Environment(\.dismiss) private var dismiss: DismissAction

    var availableRoles: [Role] {
        roles.filter { !existingRoleIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if availableRoles.isEmpty {
                    Text(t.t("admin.all_roles_assigned"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableRoles) { role in
                        Button {
                            onAssign(role.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.name.capitalized)
                                    .font(.headline)

                                if let description = role.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(t.t("admin.assign_role"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) { dismiss() }
                }
            }
        }
        .presentationDetents([PresentationDetent.medium])
    }
}


#endif
