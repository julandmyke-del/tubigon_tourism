import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../map/providers/map_provider.dart';
import '../../providers/lgu_providers.dart';

class LguTourismMonitoringPage extends ConsumerStatefulWidget {
  const LguTourismMonitoringPage({super.key});
  @override
  ConsumerState<LguTourismMonitoringPage> createState() => _State();
}

class _State extends ConsumerState<LguTourismMonitoringPage> {
  String _filter = 'submitted';
  @override
  Widget build(BuildContext context) {
    final listings = ref
        .watch(lguTourismListingsProvider(_filter == 'all' ? null : _filter));
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Partner Listing Review',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold)),
          const Text('Municipal review of submitted tourism partner offerings.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final value in const [
              'all',
              'submitted',
              'approved',
              'needs_changes',
              'suspended'
            ])
              ChoiceChip(
                  label: Text(value.replaceAll('_', ' ')),
                  selected: _filter == value,
                  onSelected: (_) => setState(() => _filter = value)),
          ]),
          const SizedBox(height: 12),
          Expanded(
              child: listings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton(
                    onPressed: () => ref.invalidate(lguTourismListingsProvider),
                    child: Text('Retry: $error'))),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('No partner listings in this state.',
                        style: TextStyle(color: AppColors.grey400)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        tileColor: const Color(0xFF1C2541),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        leading: const Icon(Icons.tour_rounded,
                            color: AppColors.warning),
                        title: Text(
                            item['listing_name']?.toString() ??
                                'Tourism listing',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${item['listing_type'] ?? 'service'} • ${item['address'] ?? 'No address'}\n${item['approval_status'] ?? 'draft'}',
                            style: const TextStyle(color: AppColors.grey400)),
                        isThreeLine: true,
                        trailing: ElevatedButton(
                            onPressed: () => _review(item),
                            child: const Text('Review')),
                      );
                    },
                  ),
          )),
        ]),
      ),
    );
  }

  Future<void> _review(Map<String, dynamic> item) async {
    String decision = 'approved';
    final notes = TextEditingController();
    final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text('Review ${item['listing_name'] ?? 'listing'}'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        '${item['description'] ?? ''}\n${item['latitude'] ?? '—'}, ${item['longitude'] ?? '—'}'),
                    DropdownButtonFormField<String>(
                        initialValue: decision,
                        items: const [
                          DropdownMenuItem(
                              value: 'approved',
                              child: Text('Approve and publish')),
                          DropdownMenuItem(
                              value: 'needs_changes',
                              child: Text('Needs changes')),
                          DropdownMenuItem(
                              value: 'rejected', child: Text('Reject')),
                          DropdownMenuItem(
                              value: 'suspended', child: Text('Suspend')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => decision = value ?? decision)),
                    TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Review notes')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Save'))
                  ],
                )));
    if (save != true) return;
    if (decision != 'approved' && notes.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notes are required for this decision.')));
      }
      return;
    }
    try {
      await ref.read(lguRepositoryProvider).reviewTourismListing(
          item['id'].toString(), decision,
          notes: notes.text.trim().isEmpty ? null : notes.text.trim());
      ref.invalidate(lguTourismListingsProvider);
      ref.invalidate(lguDashboardStatsProvider);
      ref.invalidate(mapMarkersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Listing review saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.error, content: Text(error.toString())));
      }
    }
  }
}
