import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalAvailabilityPage extends ConsumerStatefulWidget {
  const MsmePortalAvailabilityPage({super.key});
  @override
  ConsumerState<MsmePortalAvailabilityPage> createState() => _State();
}

class _State extends ConsumerState<MsmePortalAvailabilityPage> {
  String? _status;
  final _dates = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _dates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(msmePortalProfileProvider);
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: OutlinedButton(
                  onPressed: () => ref.invalidate(msmePortalProfileProvider),
                  child: Text('Retry: $error'))),
          data: (data) {
            if (data.isEmpty) {
              return const Center(
                  child: Text('Create your business profile first.',
                      style: TextStyle(color: MsmeTheme.textMuted)));
            }
            _status ??= data['operational_status']?.toString() ?? 'open';
            if (_dates.text.isEmpty && data['unavailable_dates'] is List) {
              _dates.text = (data['unavailable_dates'] as List).join(', ');
            }
            return ListView(children: [
              Text('Operational Availability', style: MsmeTheme.headingLarge()),
              const Text(
                  'This is separate from verification and affects new bookings.',
                  style: TextStyle(color: MsmeTheme.textMuted)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: MsmeTheme.cardDecoration(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        items: const [
                          DropdownMenuItem(value: 'open', child: Text('Open')),
                          DropdownMenuItem(
                              value: 'temporarily_closed',
                              child: Text('Temporarily closed')),
                          DropdownMenuItem(
                              value: 'fully_booked',
                              child: Text('Fully booked')),
                        ],
                        onChanged: (value) => setState(() => _status = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _dates,
                          decoration: const InputDecoration(
                              labelText: 'Unavailable dates',
                              hintText: '2026-09-01, 2026-09-02')),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Save availability')),
                    ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final dates = _dates.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (dates.any((item) => !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(item))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Use YYYY-MM-DD dates separated by commas.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(msmePortalRepositoryProvider).updateProfile(
          {'operational_status': _status, 'unavailable_dates': dates});
      ref.invalidate(msmePortalProfileProvider);
      ref.invalidate(msmePortalDashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: MsmeTheme.green,
            content: Text('Availability saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: MsmeTheme.red, content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
