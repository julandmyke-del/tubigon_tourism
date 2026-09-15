import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../providers/admin_providers.dart';

class AdminUserDetailPage extends ConsumerWidget {
  const AdminUserDetailPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(adminUserProvider(userId));
    return Scaffold(
      backgroundColor: AdminColors.navy950,
      appBar: AppBar(
        backgroundColor: AdminColors.navy900,
        foregroundColor: AdminColors.textPrimary,
        title: const Text('User Detail'),
        actions: [
          IconButton(
            tooltip: 'Revoke active sessions',
            onPressed: () async {
              try {
                await ref
                    .read(adminRepositoryProvider)
                    .revokeUserSessions(userId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User sessions revoked.')),
                );
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to revoke sessions.')),
                );
              }
            },
            icon: const Icon(Icons.logout_rounded),
          ),
          IconButton(
            tooltip: 'Edit user',
            onPressed: () => context.push('/admin/users/$userId/edit'),
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: user.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdminColors.orange),
        ),
        error: (_, __) => _LoadFailure(
          message: 'Unable to load this user.',
          onRetry: () => ref.invalidate(adminUserProvider(userId)),
        ),
        data: (data) {
          final roleName = data['role'] is Map
              ? (data['role']['name'] ?? 'unknown').toString()
              : (data['role'] ?? data['role_name'] ?? 'unknown').toString();
          final msmes = data['linked_msmes'] as List<dynamic>? ?? const [];
          final spots =
              data['linked_tourist_spots'] as List<dynamic>? ?? const [];
          final activity =
              data['recent_activity'] as List<dynamic>? ?? const [];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _Header(
                name: (data['name'] ?? 'Unnamed user').toString(),
                role: _label(roleName),
                verified: data['is_verified'] == true ||
                    data['is_verified'] == 1 ||
                    data['is_verified'] == '1',
              ),
              const SizedBox(height: 20),
              _DetailsCard(rows: {
                'User ID': (data['id'] ?? userId).toString(),
                'Email': (data['email'] ?? 'Not provided').toString(),
                'Phone': (data['phone'] ?? 'Not provided').toString(),
                'Language': (data['language'] ?? 'Not recorded').toString(),
                'Bio': (data['bio'] ?? 'Not provided').toString(),
                'Created': (data['created_at'] ?? 'Not recorded').toString(),
                'Account status': (data['status'] ?? 'Unknown').toString(),
              }),
              const SizedBox(height: 16),
              _DetailsCard(rows: {
                'Linked MSME': msmes.isEmpty
                    ? 'None'
                    : msmes.map((item) => item['name']).join(', '),
                'Linked Spots': spots.isEmpty
                    ? 'None'
                    : spots.map((item) => item['name']).join(', '),
              }),
              if (roleName == 'tourism_partner') ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _managePartnerAssignment(
                      context,
                      ref,
                      spots.isEmpty ? null : spots.first['id']?.toString(),
                    ),
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: const Text('Manage Destination Assignment'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                color: AdminColors.navy900,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Activity',
                          style: TextStyle(
                              color: AdminColors.textPrimary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (activity.isEmpty)
                        Text('No recent activity.',
                            style: TextStyle(color: AdminColors.textSecondary))
                      else
                        ...activity.map((item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  (item['action'] ?? 'Activity').toString(),
                                  style: TextStyle(
                                      color: AdminColors.textPrimary)),
                              subtitle: Text(
                                  (item['created_at'] ?? '').toString(),
                                  style: TextStyle(
                                      color: AdminColors.textSecondary)),
                            )),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _managePartnerAssignment(
    BuildContext context,
    WidgetRef ref,
    String? currentSpotId,
  ) async {
    final repository = ref.read(adminRepositoryProvider);
    final spotsFuture = ref.read(adminSpotsProvider.future);
    try {
      final spots = await spotsFuture;
      if (!context.mounted) return;
      String? selected = currentSpotId;
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Destination Assignment'),
            content: SizedBox(
              width: 480,
              child: DropdownButtonFormField<String?>(
                initialValue: selected,
                decoration:
                    const InputDecoration(labelText: 'Assigned Tourist Spot'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('No destination assigned')),
                  ...spots.map((spot) => DropdownMenuItem<String?>(
                        value: spot['id']?.toString(),
                        child: Text('${spot['name'] ?? 'Tourist Spot'}'),
                      )),
                ],
                onChanged: (value) => setDialogState(() => selected = value),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save Assignment')),
            ],
          ),
        ),
      );
      if (save != true || !context.mounted) return;
      await repository.updatePartnerAssignment(userId, selected);
      if (!context.mounted) return;
      ref.invalidate(adminUserProvider(userId));
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminSpotsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Partner destination assignment updated.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to update this destination assignment.')),
      );
    }
  }
}

class AdminUserEditPage extends ConsumerStatefulWidget {
  const AdminUserEditPage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminUserEditPage> createState() => _AdminUserEditPageState();
}

class _AdminUserEditPageState extends ConsumerState<AdminUserEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  final _language = TextEditingController();
  String? _roleId;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    _language.dispose();
    super.dispose();
  }

  void _initialize(Map<String, dynamic> user) {
    if (_initialized) return;
    _initialized = true;
    _name.text = (user['name'] ?? '').toString();
    _phone.text = (user['phone'] ?? '').toString();
    _bio.text = (user['bio'] ?? '').toString();
    _language.text = (user['language'] ?? 'en').toString();
    _roleId = user['role_id']?.toString();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).updateUser(widget.userId, {
        'name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'language': _language.text.trim(),
        'role_id': _roleId,
      });
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminUserProvider(widget.userId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User account updated.')),
      );
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to update this user account.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(adminUserProvider(widget.userId));
    final roles = ref.watch(adminRolesProvider);
    return Scaffold(
      backgroundColor: AdminColors.navy950,
      appBar: AppBar(
        backgroundColor: AdminColors.navy900,
        foregroundColor: AdminColors.textPrimary,
        title: const Text('Edit User'),
      ),
      body: user.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdminColors.orange),
        ),
        error: (_, __) => _LoadFailure(
          message: 'Unable to load this user.',
          onRetry: () => ref.invalidate(adminUserProvider(widget.userId)),
        ),
        data: (data) {
          _initialize(data);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _field(_name, 'Name', required: true),
                _field(_phone, 'Phone'),
                _field(_bio, 'Bio', lines: 4),
                _field(_language, 'Language', required: true),
                roles.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text(
                    'Roles could not be loaded.',
                    style: TextStyle(color: AdminColors.danger),
                  ),
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue:
                        items.any((role) => role['id']?.toString() == _roleId)
                            ? _roleId
                            : null,
                    dropdownColor: AdminColors.navy900,
                    style: TextStyle(color: AdminColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: items
                        .map((role) => DropdownMenuItem(
                              value: role['id']?.toString(),
                              child: Text(_label(
                                  (role['name'] ?? 'unknown').toString())),
                            ))
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Select a role.' : null,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _roleId = value),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: AdminColors.danger)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        maxLines: lines,
        style: TextStyle(color: AdminColors.textPrimary),
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? '$label is required.'
                : null
            : null,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.role,
    required this.verified,
  });

  final String name;
  final String role;
  final bool verified;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AdminColors.orangeDim,
            child: Text(
              name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AdminColors.orange,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text('$role • ${verified ? 'Verified' : 'Unverified'}',
                    style: TextStyle(color: AdminColors.textSecondary)),
              ],
            ),
          ),
        ],
      );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => Card(
        color: AdminColors.navy900,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: rows.entries
                .map((row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(row.key,
                                style: TextStyle(
                                    color: AdminColors.textSecondary)),
                          ),
                          Expanded(
                            child: SelectableText(row.value,
                                style: TextStyle(
                                    color: AdminColors.textPrimary)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                style: TextStyle(color: AdminColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

String _label(String value) => value
    .split('_')
    .map((part) => part.isEmpty
        ? part
        : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}')
    .join(' ');
