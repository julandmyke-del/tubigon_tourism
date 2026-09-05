import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  String _statusFilter = 'All';

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
    final users = usersAsync.valueOrNull ?? const <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                        ref.invalidate(adminDashboardStatsProvider);
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
                      onPressed: rolesAsync.hasValue
                          ? () => _showAddUserDialog(
                              context, rolesAsync.value ?? const [])
                          : null,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add New User',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _UserStat(label: 'Total Users', value: users.length),
                  for (final role in const [
                    'tourist',
                    'msme_owner',
                    'tourism_partner',
                    'lgu_staff',
                    'admin'
                  ]) ...[
                    const SizedBox(width: 10),
                    _UserStat(
                      label: role
                          .split('_')
                          .map((part) =>
                              '${part[0].toUpperCase()}${part.substring(1)}')
                          .join(' '),
                      value: users
                          .where((user) =>
                              (user['role'] ?? user['role_name']) == role)
                          .length,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Search & Filter Controls
            Container(
              decoration: AdminColors.glassDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
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
                          'admin',
                          'tourism_partner'
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
                        value: _statusFilter,
                        style: const TextStyle(
                            color: AdminColors.textPrimary, fontSize: 14),
                        items: const [
                          DropdownMenuItem(
                              value: 'All', child: Text('All Statuses')),
                          DropdownMenuItem(
                              value: 'Active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'Disabled', child: Text('Disabled')),
                        ],
                        onChanged: (val) =>
                            setState(() => _statusFilter = val!),
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
                      final status = (u['status'] ?? 'Active').toString();

                      final matchesQuery =
                          name.contains(_searchQuery.toLowerCase()) ||
                              email.contains(_searchQuery.toLowerCase());
                      final matchesRole = _roleFilter == 'All' ||
                          role == _roleFilter.toLowerCase();
                      final matchesVerification = _verificationFilter ==
                              'All' ||
                          (_verificationFilter == 'Verified' && isVerified) ||
                          (_verificationFilter == 'Pending' && !isVerified);
                      final matchesStatus =
                          _statusFilter == 'All' || status == _statusFilter;

                      return matchesQuery &&
                          matchesRole &&
                          matchesVerification &&
                          matchesStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                            'No users match the search and filter criteria.',
                            style: TextStyle(color: AdminColors.textSecondary)),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 820) {
                          return ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) => _buildUserCard(
                              filtered[index],
                              rolesAsync.valueOrNull,
                            ),
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
                                    label: Text('LINKED ACCOUNT',
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
                                final name =
                                    (u['name'] ?? u['full_name'] ?? 'User')
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
                                final status =
                                    (u['status'] ?? 'Active').toString();
                                final userId = u['id']?.toString() ??
                                    u['uuid']?.toString() ??
                                    '';
                                final linked = role == 'msme_owner'
                                    ? (u['linked_msmes'] as List<dynamic>? ??
                                        const [])
                                    : (u['linked_tourist_spots']
                                            as List<dynamic>? ??
                                        const []);
                                final linkedLabel = linked.isEmpty
                                    ? '—'
                                    : linked
                                        .map((item) =>
                                            item['name']?.toString() ?? '')
                                        .where((name) => name.isNotEmpty)
                                        .join(', ');

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor:
                                                AdminColors.orangeDim,
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
                                                  color:
                                                      AdminColors.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      onTap: userId.isEmpty
                                          ? null
                                          : () => context
                                              .push('/admin/users/$userId'),
                                    ),
                                    DataCell(Text(email,
                                        style: const TextStyle(
                                            color: AdminColors.textSecondary,
                                            fontSize: 13))),
                                    DataCell(_RoleBadge(role: role)),
                                    DataCell(SizedBox(
                                      width: 160,
                                      child: Text(linkedLabel,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AdminColors.textSecondary,
                                              fontSize: 12)),
                                    )),
                                    DataCell(
                                      InkWell(
                                        onTap: () async {
                                          try {
                                            await ref
                                                .read(adminRepositoryProvider)
                                                .updateUserActivation(
                                                    userId, !isVerified);
                                            if (!mounted) return;
                                            ref.invalidate(adminUsersProvider);
                                            ref.invalidate(
                                                adminDashboardStatsProvider);
                                            _showMessage(
                                                'User verification updated.');
                                          } catch (_) {
                                            _showMessage(
                                                'Unable to update user verification.',
                                                error: true);
                                          }
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
                                    DataCell(
                                      InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => _setAccountStatus(
                                            userId, name, status != 'Active'),
                                        child: _StatusBadge(status: status),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                color: AdminColors.info,
                                                size: 18),
                                            tooltip: 'Edit User Role',
                                            onPressed: () =>
                                                _showEditRoleDialog(
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
                    );
                  },
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AdminColors.orange)),
                  error: (err, _) => const Center(
                      child: Text('Unable to load users. Use Refresh to retry.',
                          style: TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(
      BuildContext context, List<Map<String, dynamic>> roles) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? selectedRoleId = roles
        .where((role) => role['name'] == 'tourist')
        .map((role) => role['id']?.toString())
        .firstOrNull;
    selectedRoleId ??= roles.firstOrNull?['id']?.toString();
    var saving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
                backgroundColor: AdminColors.navy900,
                title: const Text('Add New System User',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          style:
                              const TextStyle(color: AdminColors.textPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Full Name',
                              labelStyle:
                                  TextStyle(color: AdminColors.textSecondary)),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Full name is required.'
                                  : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style:
                              const TextStyle(color: AdminColors.textPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Email Address',
                              labelStyle:
                                  TextStyle(color: AdminColors.textSecondary)),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            return email.contains('@')
                                ? null
                                : 'Enter a valid email.';
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: passCtrl,
                          obscureText: true,
                          style:
                              const TextStyle(color: AdminColors.textPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Password',
                              labelStyle:
                                  TextStyle(color: AdminColors.textSecondary)),
                          validator: (value) => (value?.length ?? 0) < 8
                              ? 'Password must be at least 8 characters.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRoleId,
                          dropdownColor: AdminColors.navy900,
                          style:
                              const TextStyle(color: AdminColors.textPrimary),
                          decoration: const InputDecoration(
                              labelText: 'System Role',
                              labelStyle:
                                  TextStyle(color: AdminColors.textSecondary)),
                          items: roles
                              .map((role) => DropdownMenuItem(
                                  value: role['id']?.toString(),
                                  child: Text((role['name'] ?? 'role')
                                      .toString()
                                      .toUpperCase())))
                              .toList(),
                          onChanged:
                              saving ? null : (val) => selectedRoleId = val,
                          validator: (value) =>
                              value == null ? 'Select a role.' : null,
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(errorMessage!,
                              style:
                                  const TextStyle(color: AdminColors.danger)),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text('Cancel',
                        style: TextStyle(color: AdminColors.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.orange),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            setDialogState(() {
                              saving = true;
                              errorMessage = null;
                            });
                            try {
                              await ref
                                  .read(adminRepositoryProvider)
                                  .createUser({
                                'name': nameCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'password': passCtrl.text,
                                'role_id': selectedRoleId,
                              });
                              if (!mounted) return;
                              ref.invalidate(adminUsersProvider);
                              ref.invalidate(adminDashboardStatsProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _showMessage('User created.');
                            } catch (_) {
                              if (ctx.mounted) {
                                setDialogState(() {
                                  saving = false;
                                  errorMessage =
                                      'Unable to create this user. Check the email and role.';
                                });
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create User',
                            style: TextStyle(color: Colors.white)),
                  ),
                ],
              )),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
    List<Map<String, dynamic>>? roles,
  ) {
    final name = (user['name'] ?? user['full_name'] ?? 'User').toString();
    final email = (user['email'] ?? '').toString();
    final role = (user['role'] ?? user['role_name'] ?? 'tourist').toString();
    final isVerified = user['is_verified'] == true ||
        user['is_verified'] == 1 ||
        user['is_verified'] == '1';
    final status = (user['status'] ?? 'Active').toString();
    final userId = user['id']?.toString() ?? user['uuid']?.toString() ?? '';
    final linked = role == 'msme_owner'
        ? (user['linked_msmes'] as List<dynamic>? ?? const [])
        : (user['linked_tourist_spots'] as List<dynamic>? ?? const []);
    final linkedLabel = linked
        .map((item) => item['name']?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .join(', ');

    return Material(
      color: AdminColors.navy900,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            userId.isEmpty ? null : () => context.push('/admin/users/$userId'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AdminColors.orangeDim,
                    child: Text(
                      name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AdminColors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AdminColors.textPrimary,
                                fontWeight: FontWeight.w700)),
                        Text(email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AdminColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AdminColors.textSecondary),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RoleBadge(role: role),
                  _VerificationBadge(isVerified: isVerified),
                  _StatusBadge(status: status),
                ],
              ),
              if (linkedLabel.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Linked: $linkedLabel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AdminColors.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(_formatCreatedAt(user['created_at']),
                      style: const TextStyle(
                          color: AdminColors.textSecondary, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Edit user role',
                    onPressed: userId.isEmpty
                        ? null
                        : () => _showEditRoleDialog(
                            context, userId, name, role, roles),
                    icon: const Icon(Icons.manage_accounts_outlined,
                        color: AdminColors.info),
                  ),
                  IconButton(
                    tooltip: status == 'Active'
                        ? 'Deactivate account'
                        : 'Activate account',
                    onPressed: userId.isEmpty
                        ? null
                        : () =>
                            _setAccountStatus(userId, name, status != 'Active'),
                    icon: Icon(
                      status == 'Active'
                          ? Icons.person_off_outlined
                          : Icons.person_add_alt_outlined,
                      color: status == 'Active'
                          ? AdminColors.danger
                          : AdminColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setAccountStatus(
      String userId, String name, bool active) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: Text('${active ? 'Activate' : 'Deactivate'} account?',
            style: const TextStyle(color: AdminColors.textPrimary)),
        content: Text(name,
            style: const TextStyle(color: AdminColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(active ? 'Activate' : 'Deactivate')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await ref.read(adminRepositoryProvider).updateUserStatus(userId, active);
      if (!mounted) return;
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminDashboardStatsProvider);
      ref.invalidate(adminUserProvider(userId));
      _showMessage('Account ${active ? 'activated' : 'deactivated'}.');
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to change this account status.', error: true);
      }
    }
  }

  void _showEditRoleDialog(BuildContext context, String userId, String name,
      String currentRole, List<Map<String, dynamic>>? roles) {
    final availableRoles = roles ?? const <Map<String, dynamic>>[];
    String? selectedRoleId = availableRoles
        .where((role) => role['name'] == currentRole)
        .map((role) => role['id']?.toString())
        .firstOrNull;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: Text('Edit Role: $name',
            style: const TextStyle(
                color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        content: DropdownButtonFormField<String>(
          initialValue: selectedRoleId,
          dropdownColor: AdminColors.navy900,
          style: const TextStyle(color: AdminColors.textPrimary),
          decoration: const InputDecoration(
              labelText: 'Assigned Role',
              labelStyle: TextStyle(color: AdminColors.textSecondary)),
          items: availableRoles
              .map((role) => DropdownMenuItem(
                  value: role['id']?.toString(),
                  child:
                      Text((role['name'] ?? 'role').toString().toUpperCase())))
              .toList(),
          onChanged: (val) => selectedRoleId = val,
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
              if (selectedRoleId == null) return;
              try {
                await ref
                    .read(adminRepositoryProvider)
                    .updateUserRole(userId, selectedRoleId!);
                if (!mounted) return;
                ref.invalidate(adminUsersProvider);
                ref.invalidate(adminDashboardStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                _showMessage('User role updated.');
              } catch (_) {
                _showMessage('Unable to update this user role.', error: true);
              }
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
        title: const Text('Archive User',
            style: TextStyle(color: AdminColors.textPrimary)),
        content: Text(
            'Archive "$name"? The account will no longer be able to sign in.',
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
              try {
                await ref.read(adminRepositoryProvider).deleteUser(userId);
                if (!mounted) return;
                ref.invalidate(adminUsersProvider);
                ref.invalidate(adminDashboardStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                _showMessage('User archived.');
              } catch (_) {
                if (ctx.mounted) Navigator.pop(ctx);
                _showMessage(
                    'Unable to archive this account. It may be your account or the last Admin.',
                    error: true);
              }
            },
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AdminColors.danger : AdminColors.success,
    ));
  }
}

class _UserStat extends StatelessWidget {
  const _UserStat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: AdminColors.glassDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AdminColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
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
