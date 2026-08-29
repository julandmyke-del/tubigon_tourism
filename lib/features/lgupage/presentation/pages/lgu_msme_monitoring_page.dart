import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../map/providers/map_provider.dart';
import '../../../msmepage/repositories/msme_repository.dart';
import '../../providers/lgu_providers.dart';

class LguMsmeMonitoringPage extends ConsumerStatefulWidget {
  const LguMsmeMonitoringPage({super.key});
  @override
  ConsumerState<LguMsmeMonitoringPage> createState() => _State();
}

class _State extends ConsumerState<LguMsmeMonitoringPage> {
  String _filter = 'pending';

  @override
  Widget build(BuildContext context) {
    final msmes =
        ref.watch(lguMsmesProvider(_filter == 'all' ? null : _filter));
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MSME Verification',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold)),
          const Text(
              'Review real owner profiles, locations, and submitted information.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (final value in const [
              'all',
              'pending',
              'verified',
              'needs_changes',
              'suspended'
            ])
              ChoiceChip(
                  label: Text(value.replaceAll('_', ' ')),
                  selected: _filter == value,
                  onSelected: (_) => setState(() => _filter = value)),
          ]),
          const SizedBox(height: 14),
          Expanded(
              child: msmes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton(
              onPressed: () => ref.invalidate(lguMsmesProvider),
              child: Text('Retry: $error'),
            )),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('No MSMEs in this review state.',
                        style: TextStyle(color: AppColors.grey400)))
                : RefreshIndicator(
                    onRefresh: () async => ref.refresh(
                        lguMsmesProvider(_filter == 'all' ? null : _filter)
                            .future),
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _card(items[index]),
                    ),
                  ),
          )),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final profile = item['profile'];
    final status = item['verification_status']?.toString() ??
        (item['is_verified'] == true ? 'verified' : 'pending');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1C2541),
          borderRadius: BorderRadius.circular(14)),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 10,
          children: [
            SizedBox(
                width: 520,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name']?.toString() ?? 'Business',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text(
                          'Owner: ${profile is Map ? profile['name'] ?? 'Owner' : 'Owner'} • ${item['category'] ?? 'Uncategorized'}',
                          style: const TextStyle(color: AppColors.grey400)),
                      Text(
                          '${item['address'] ?? 'Address not supplied'}\n${item['phone'] ?? 'Contact not supplied'}',
                          style: const TextStyle(color: AppColors.grey400)),
                      Text(
                          'Coordinates: ${item['latitude'] ?? '—'}, ${item['longitude'] ?? '—'}',
                          style: const TextStyle(color: AppColors.grey400)),
                      Chip(label: Text(status.toUpperCase())),
                      if ((item['verification_notes']?.toString() ?? '')
                          .isNotEmpty)
                        Text(item['verification_notes'].toString(),
                            style: const TextStyle(color: AppColors.warning)),
                    ])),
            ElevatedButton.icon(
                onPressed: () => _review(item),
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('Review')),
          ]),
    );
  }

  Future<void> _review(Map<String, dynamic> item) async {
    final notes = TextEditingController();
    String decision = 'verified';
    final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: Text('Review ${item['name'] ?? 'MSME'}'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    initialValue: decision,
                    items: const [
                      DropdownMenuItem(
                          value: 'verified', child: Text('Verified')),
                      DropdownMenuItem(
                          value: 'needs_changes', child: Text('Needs changes')),
                      DropdownMenuItem(
                          value: 'suspended', child: Text('Suspended')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => decision = value ?? 'verified'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Reason / notes')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Save decision')),
                ],
              ),
            ));
    if (approved != true) return;
    if (decision != 'verified' && notes.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notes are required for this decision.')));
      }
      return;
    }
    try {
      await ref.read(lguRepositoryProvider).verifyMsme(
            item['id'].toString(),
            decision == 'verified',
            status: decision,
            notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          );
      ref.invalidate(lguMsmesProvider);
      ref.invalidate(lguDashboardStatsProvider);
      ref.invalidate(msmeListProvider);
      ref.invalidate(mapMarkersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('MSME review saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.error, content: Text(error.toString())));
      }
    }
  }
}
