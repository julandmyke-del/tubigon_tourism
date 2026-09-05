import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerProfilePage extends ConsumerStatefulWidget {
  const PartnerProfilePage({super.key});
  @override
  ConsumerState<PartnerProfilePage> createState() => _State();
}

class _State extends ConsumerState<PartnerProfilePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(partnerProfileProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: OutlinedButton(
            onPressed: () => ref.invalidate(partnerProfileProvider),
            child: const Text("We couldn't load your profile. Retry"),
          )),
          data: (data) {
            if (!_initialized) {
              _name.text = data['name']?.toString() ?? '';
              _phone.text = data['phone']?.toString() ?? '';
              _bio.text = data['bio']?.toString() ?? '';
              _initialized = true;
            }
            return ListView(children: [
              Text('Partner Profile', style: PartnerTheme.headingLarge()),
              Text(
                  'Manage your account details and review the Admin-controlled destination assignment.',
                  style: PartnerTheme.label()),
              const SizedBox(height: 18),
              _AssignmentCard(assignment: data['assignment']),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: PartnerTheme.cardDecoration(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account email', style: PartnerTheme.label()),
                      Text(data['email']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      Text('Role', style: PartnerTheme.label()),
                      const Text('Tourism Partner',
                          style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 14),
                      TextField(
                          controller: _name,
                          decoration:
                              const InputDecoration(labelText: 'Display name')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _phone,
                          decoration:
                              const InputDecoration(labelText: 'Phone')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _bio,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'About')),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 15,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: const Text('Save profile'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _changePassword,
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text('Change Password'),
                      ),
                    ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final repository = ref.read(tourismPartnerRepositoryProvider);
    setState(() => _saving = true);
    try {
      await repository.updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'bio': _bio.text.trim(),
      });
      if (mounted) {
        _initialized = false;
        ref.invalidate(partnerProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: PartnerTheme.green,
              content: Text('Profile saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: PartnerTheme.red,
              content: Text("We couldn't save your profile.")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: TextField(
          controller: password,
          obscureText: true,
          decoration:
              const InputDecoration(labelText: 'New password (6+ characters)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, password.text.length >= 6),
              child: const Text('Update')),
        ],
      ),
    );
    final value = password.text;
    password.dispose();
    if (confirmed != true || !mounted) return;
    final repository = ref.read(tourismPartnerRepositoryProvider);
    setState(() => _saving = true);
    try {
      await repository.updatePassword(value);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Password updated.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("We couldn't update the password.")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});
  final Object? assignment;
  @override
  Widget build(BuildContext context) {
    if (assignment is! Map || (assignment as Map)['destination'] is! Map) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: PartnerTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Destination Assignment', style: PartnerTheme.headingSmall()),
          const SizedBox(height: 8),
          const Text('No destination assigned',
              style: TextStyle(
                  color: PartnerTheme.orange, fontWeight: FontWeight.bold)),
          Text('Contact the Tourism Office or wait for Admin assignment.',
              style: PartnerTheme.label()),
        ]),
      );
    }
    final data = assignment as Map;
    final destination = data['destination'] as Map;
    final assignedBy = data['assigned_by'] is Map
        ? (data['assigned_by'] as Map)['name']
        : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PartnerTheme.cardDecoration(),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 12,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Destination Assignment',
                  style: PartnerTheme.headingSmall()),
              const SizedBox(height: 8),
              Text('${destination['name'] ?? 'Tourist Spot'}',
                  style: const TextStyle(
                      color: PartnerTheme.primaryOrange,
                      fontWeight: FontWeight.w800)),
              const Text('ACTIVE • Admin controlled',
                  style: TextStyle(color: PartnerTheme.green)),
              Text('Assigned: ${data['assigned_at'] ?? '—'}',
                  style: PartnerTheme.label()),
              Text('Assigned by: ${assignedBy ?? 'Tourism Office'}',
                  style: PartnerTheme.label()),
            ]),
            Wrap(spacing: 8, children: [
              OutlinedButton(
                  onPressed: () => context.go('/tourism-partner/listings'),
                  child: const Text('View Destination')),
              OutlinedButton(
                  onPressed: () => context
                      .push('/map?marker=tourist_spot:${destination['id']}'),
                  child: const Text('View on Map')),
            ]),
          ]),
    );
  }
}
