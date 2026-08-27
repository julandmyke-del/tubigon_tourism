import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminUserManagementPage extends ConsumerStatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  ConsumerState<AdminUserManagementPage> createState() =>
      _AdminUserManagementPageState();
}

class _AdminUserManagementPageState
    extends ConsumerState<AdminUserManagementPage> {
  String _searchQuery = '';
  String _roleFilter = 'All';
  String _verificationFilter = 'All';

  String _formatCreatedAt(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? '—'
        : DateFormat('MMM d, yyyy').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final rolesAsync = ref.watch(adminRolesProvider);

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inspect system registry, modify access roles, and manage user accounts.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AdminColors.cardBg,
                        side: const BorderSide(color: AdminColors.cardBorder),
                      ),
                      onPressed: () {
                        ref.invalidate(adminUsersProvider);
                        ref.invalidate(adminRolesProvider);
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          color: AdminColors.orange),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showAddUserDialog(context),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add New User',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Search & Filter Controls
            Container(
              decoration: AdminColors.glassDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(
                          color: AdminColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search users by name or email...',
                        hintStyle:
                            const TextStyle(color: AdminColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AdminColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AdminColors.navy900,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AdminColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AdminColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AdminColors.borderActive),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AdminColors.navy900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: AdminColors.navy900,
                        value: _roleFilter,
                        icon: const Icon(Icons.filter_list_rounded,
                            color: AdminColors.textSecondary),
                        style: const TextStyle(
                            color: AdminColors.textPrimary, fontSize: 14),
                        items: [
                          'All',
                          'tourist',
                          'msme_owner',
                          'lgu_staff',
                          'admin'
                        ]
                            .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r == 'All'
                                    ? 'All Roles'
                                    : r.toUpperCase())))
                            .toList(),
                        onChanged: (val) => setState(() => _roleFilter = val!),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AdminColors.navy900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: AdminColors.navy900,
                        value: _verificationFilter,
                        icon: const Icon(Icons.mark_email_read_rounded,
                            color: AdminColors.textSecondary),
                        style: const TextStyle(
                            color: AdminColors.textPrimary, fontSize: 14),
                        items: const [
                          DropdownMenuItem(
                              value: 'All', child: Text('All Verification')),
                          DropdownMenuItem(
                              value: 'Verified', child: Text('Verified Only')),
                          DropdownMenuItem(
                              value: 'Pending', child: Text('Pending Only')),
                        ],
                        onChanged: (val) =>
                            setState(() => _verificationFilter = val!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Users Table Area
            Expanded(
              child: Container(
                decoration: AdminColors.glassDecoration(),
                clipBehavior: Clip.antiAlias,
                child: usersAsync.when(
                  data: (users) {
                    final filtered = users.where((u) {
                      final name = (u['name'] ?? u['full_name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final email = (u['email'] ?? '').toString().toLowerCase();
                      final role = (u['role'] ?? u['role_name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final isVerified = u['is_verified'] == true ||
                          u['is_verified'] == 1 ||
                          u['is_verified'] == '1';

                      final matchesQuery =
                          name.contains(_searchQuery.toLowerCase()) ||
                              email.contains(_searchQuery.toLowerCase());
                      final matchesRole = _roleFilter == 'All' ||
                          role == _roleFilter.toLowerCase();
                      final matchesVerification = _verificationFilter ==
                              'All' ||
                          (_verificationFilter == 'Verified' && isVerified) ||
                          (_verificationFilter == 'Pending' && !isVerified);

                      return matchesQuery && matchesRole && matchesVerification;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                            'No users match the search and filter criteria.',
                            style: TextStyle(color: AdminColors.textSecondary)),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AdminColors.navy900),
                          dataRowColor:
                              WidgetStateProperty.all(Colors.transparent),
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(
                                label: Text('USER',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('EMAIL',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('ROLE',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('VERIFICATION',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('METHOD',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('CREATED',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('STATUS',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('ACTIONS',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                          ],
                          rows: filtered.map((u) {
                            final name = (u['name'] ?? u['full_name'] ?? 'User')
                                .toString();
                            final email = (u['email'] ?? '').toString();
                            final role =
                                (u['role'] ?? u['role_name'] ?? 'tourist')
                                    .toString();
                            final isVerified = u['is_verified'] == true ||
                                u['is_verified'] == 1 ||
                                u['is_verified'] == '1';
                            final registrationMethod =
                                (u['registration_method'] ?? 'email')
                                    .toString();
                            final status = (u['status'] ?? 'Active').toString();
                            final userId = u['id']?.toString() ??
                                u['uuid']?.toString() ??
                                '';

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AdminColors.orangeDim,
                                        child: Text(
                                          name.isNotEmpty
                                              ? name
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                              color: AdminColors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(name,
                                          style: const TextStyle(
                                              color: AdminColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(email,
                                    style: const TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontSize: 13))),
                                DataCell(_RoleBadge(role: role)),
                                DataCell(
                                  InkWell(
                                    onTap: () async {
                                      final repo =
                                          ref.read(adminRepositoryProvider);
                                      await repo.updateUserActivation(
                                          userId, !isVerified);
                                      ref.invalidate(adminUsersProvider);
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: _VerificationBadge(
                                        isVerified: isVerified),
                                  ),
                                ),
                                DataCell(_RegistrationMethodBadge(
                                    method: registrationMethod)),
                                DataCell(Text(
                                  _formatCreatedAt(u['created_at']),
                                  style: const TextStyle(
                                      color: AdminColors.textSecondary,
                                      fontSize: 12),
                                )),
                                DataCell(_StatusBadge(status: status)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            color: AdminColors.info, size: 18),
                                        tooltip: 'Edit User Role',
                                        onPressed: () => _showEditRoleDialog(
                                            context,
                                            userId,
                                            name,
                                            role,
                                            rolesAsync.value),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AdminColors.danger,
                                            size: 18),
                                        tooltip: 'Delete User',
                                        onPressed: () => _confirmDeleteUser(
                                            context, userId, name),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AdminColors.orange)),
                  error: (err, _) => Center(
                      child: Text('Error loading users: $err',
                          style: const TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'tourist';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('Add New System User',
            style: TextStyle(
                color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: AdminColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(color: AdminColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: AdminColors.textSecondary)),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                dropdownColor: AdminColors.navy900,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'System Role',
                    labelStyle: TextStyle(color: AdminColors.textSecondary)),
                items: ['tourist', 'msme_owner', 'lgu_staff', 'admin']
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(r.toUpperCase())))
                    .toList(),
                onChanged: (val) => selectedRole = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AdminColors.orange),
            onPressed: () async {
              if (nameCtrl.text.isEmpty ||
                  emailCtrl.text.isEmpty ||
                  passCtrl.text.isEmpty) {
                return;
              }
              final repo = ref.read(adminRepositoryProvider);
              final success = await repo.createUser({
                'name': nameCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'password': passCtrl.text,
                'role': selectedRole,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) ref.invalidate(adminUsersProvider);
            },
            child: const Text('Create User',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditRoleDialog(BuildContext context, String userId, String name,
      String currentRole, List<Map<String, dynamic>>? roles) {
    String selectedRole = currentRole;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: Text('Edit Role: $name',
            style: const TextStyle(
                color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        content: DropdownButtonFormField<String>(
          initialValue: ['tourist', 'msme_owner', 'lgu_staff', 'admin']
                  .contains(selectedRole)
              ? selectedRole
              : 'tourist',
          dropdownColor: AdminColors.navy900,
          style: const TextStyle(color: AdminColors.textPrimary),
          decoration: const InputDecoration(
              labelText: 'Assigned Role',
              labelStyle: TextStyle(color: AdminColors.textSecondary)),
          items: ['tourist', 'msme_owner', 'lgu_staff', 'admin']
              .map((r) =>
                  DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
              .toList(),
          onChanged: (val) => selectedRole = val!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AdminColors.orange),
            onPressed: () async {
              final repo = ref.read(adminRepositoryProvider);
              final success =
                  await repo.updateUser(userId, {'role': selectedRole});
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) ref.invalidate(adminUsersProvider);
            },
            child: const Text('Save Changes',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(BuildContext context, String userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('Confirm User Deletion',
            style: TextStyle(color: AdminColors.textPrimary)),
        content: Text(
            'Are you sure you want to permanently delete user "$name"?',
            style: const TextStyle(color: AdminColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () async {
              final repo = ref.read(adminRepositoryProvider);
              final success = await repo.deleteUser(userId);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) ref.invalidate(adminUsersProvider);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color bg = AdminColors.infoBg;
    Color fg = AdminColors.info;

    if (role == 'admin') {
      bg = AdminColors.dangerBg;
      fg = AdminColors.danger;
    } else if (role == 'lgu_staff') {
      bg = AdminColors.warningBg;
      fg = AdminColors.warning;
    } else if (role == 'msme_owner') {
      bg = AdminColors.purpleBg;
      fg = AdminColors.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _RegistrationMethodBadge extends StatelessWidget {
  final String method;
  const _RegistrationMethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isGoogle = method.toLowerCase() == 'google';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGoogle
            ? const Color(0xFF1D4ED8).withValues(alpha: 0.2)
            : AdminColors.orangeDim,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isGoogle ? 'GOOGLE ACCOUNT' : 'EMAIL',
        style: TextStyle(
          color: isGoogle ? const Color(0xFF60A5FA) : AdminColors.orange,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AdminColors.successBg : AdminColors.dangerBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isActive ? AdminColors.success : AdminColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final bool isVerified;
  const _VerificationBadge({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? AdminColors.successBg : AdminColors.warningBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: isVerified ? AdminColors.success : AdminColors.warning,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? 'VERIFIED' : 'PENDING',
            style: TextStyle(
              color: isVerified ? AdminColors.success : AdminColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
