import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  String _query = '';
  String _category = 'all';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msmes =
        ref.watch(lguMsmesProvider(_filter == 'all' ? null : _filter));
    final allMsmes = ref.watch(lguMsmesProvider(null)).valueOrNull ?? const [];
    final categories =
        ref.watch(msmeCategoriesProvider).valueOrNull ?? const [];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MSME Verification',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 25,
                  fontWeight: FontWeight.bold)),
          Text(
              'Review real owner profiles, locations, and submitted information.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final value in const [
              'pending',
              'verified',
              'needs_changes',
              'suspended'
            ])
              _Summary(
                label: value,
                count: allMsmes
                    .where((item) =>
                        normalizeVerificationStatus(
                            item['verification_status']) ==
                        value)
                    .length,
                selected: _filter == value,
                onTap: () => _selectStatus(value),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                    labelText: 'Search business, owner, or category',
                    prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _category == 'all' ||
                        categories.any((item) => item.id == _category)
                    ? _category
                    : 'all',
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('All categories')),
                  ...categories.map((item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      )),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? 'all'),
              ),
            ),
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
                  onSelected: (_) => _selectStatus(value)),
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
            data: (items) {
              final filtered = items.where((item) {
                final profile = item['profile'];
                final owner = profile is Map ? profile['name'] : '';
                return (_category == 'all' ||
                        item['category_id']?.toString() == _category) &&
                    '${item['name'] ?? ''} ${item['category'] ?? ''} $owner ${item['address'] ?? ''}'
                        .toLowerCase()
                        .contains(_query);
              }).toList();
              return filtered.isEmpty
                  ? Center(
                      child: Text(
                          _filter == 'pending' &&
                                  _query.isEmpty &&
                                  _category == 'all'
                              ? 'No Pending MSMEs. Select Verified or All to view other records.'
                              : 'No MSMEs match this status and filters.',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)))
                  : RefreshIndicator(
                      onRefresh: () async => ref.refresh(
                          lguMsmesProvider(_filter == 'all' ? null : _filter)
                              .future),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _card(filtered[index]),
                      ),
                    );
            },
          )),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final profile = item['profile'];
    final status = normalizeVerificationStatus(item['verification_status']) ??
        (item['is_verified'] == true ? 'verified' : 'pending');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text(
                          'Owner: ${profile is Map ? profile['name'] ?? 'Owner' : 'Owner'} • ${item['category'] ?? 'Uncategorized'}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text(
                          '${item['address'] ?? 'Address not supplied'}\n${item['phone'] ?? 'Contact not supplied'}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text(
                          'Coordinates: ${item['latitude'] ?? '—'}, ${item['longitude'] ?? '—'}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Chip(label: Text(status.toUpperCase())),
                      if ((item['verification_notes']?.toString() ?? '')
                          .isNotEmpty)
                        Text(item['verification_notes'].toString(),
                            style: const TextStyle(color: AppColors.warning)),
                    ])),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: item['latitude'] != null && item['longitude'] != null
                    ? () => context.push('/map?marker=msme:${item['id']}')
                    : null,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Map'),
              ),
              ElevatedButton.icon(
                  onPressed: () => _review(item),
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Review Details')),
            ]),
          ]),
    );
  }

  void _selectStatus(String value) {
    setState(() {
      _filter = value;
      _query = '';
      _category = 'all';
      _search.clear();
    });
  }

  Future<void> _review(Map<String, dynamic> item) async {
    Map<String, dynamic> detail;
    try {
      detail =
          await ref.read(lguRepositoryProvider).getMsme(item['id'].toString());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (!mounted) return;
    final notes = TextEditingController();
    String decision = 'verified';
    final checklist = <String, bool>{
      'Business identity valid': (detail['name']?.toString() ?? '').isNotEmpty,
      'Owner information complete': detail['profile'] is Map,
      'Contact information valid':
          (detail['phone']?.toString() ?? '').isNotEmpty,
      'Address complete': (detail['address']?.toString() ?? '').isNotEmpty,
      'Coordinates valid':
          detail['latitude'] != null && detail['longitude'] != null,
      'Category appropriate': (detail['category']?.toString() ?? '').isNotEmpty,
      'Photos supplied': (detail['images'] as List? ?? const []).isNotEmpty,
    };
    final history = detail['review_history'] as List? ?? const [];
    final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: Text('Review ${detail['name'] ?? 'MSME'}'),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Owner: ${(detail['profile'] as Map?)?['name'] ?? 'Not supplied'}'),
                          Text(
                              'Category: ${detail['category'] ?? 'Not supplied'}'),
                          Text(
                              'Address: ${detail['address'] ?? 'Not supplied'}'),
                          Text('Phone: ${detail['phone'] ?? 'Not supplied'}'),
                          Text(
                              'Coordinates: ${detail['latitude'] ?? '—'}, ${detail['longitude'] ?? '—'}'),
                          const SizedBox(height: 12),
                          const Text('Review checklist',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          ...checklist.entries.map((entry) => CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(entry.key),
                                value: entry.value,
                                onChanged: (value) => setDialogState(() =>
                                    checklist[entry.key] = value ?? false),
                              )),
                          if (history.isNotEmpty) ...[
                            const Divider(),
                            const Text('Previous review history',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            ...history
                                .take(5)
                                .whereType<Map>()
                                .map((entry) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(entry['action']?.toString() ??
                                          'Review updated'),
                                      subtitle: Text(
                                          '${entry['actor'] ?? 'Authorized staff'} • ${entry['created_at'] ?? ''}\n${entry['notes'] ?? ''}'),
                                    )),
                          ],
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: decision,
                            items: const [
                              DropdownMenuItem(
                                  value: 'verified', child: Text('Verified')),
                              DropdownMenuItem(
                                  value: 'needs_changes',
                                  child: Text('Needs changes')),
                              DropdownMenuItem(
                                  value: 'suspended', child: Text('Suspended')),
                            ],
                            onChanged: (value) => setDialogState(
                                () => decision = value ?? 'verified'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                              controller: notes,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Review reason / note')),
                        ]),
                  ),
                ),
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
    if (!mounted || approved != true) {
      notes.dispose();
      return;
    }
    if (decision != 'verified' && notes.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notes are required for this decision.')));
      }
      notes.dispose();
      return;
    }
    try {
      await ref.read(lguRepositoryProvider).verifyMsme(
            detail['id'].toString(),
            decision == 'verified',
            status: decision,
            notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(lguMsmesProvider);
      ref.invalidate(lguDashboardStatsProvider);
      ref.invalidate(lguActivityProvider);
      ref.invalidate(lguAnalyticsProvider);
      ref.invalidate(lguReportsProvider);
      ref.invalidate(msmeListProvider);
      ref.invalidate(mapMarkersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('MSME review saved.')));
      }
    } catch (error) {
      if (mounted) {
        ref.invalidate(lguMsmesProvider);
        ref.invalidate(lguDashboardStatsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.error, content: Text(error.toString())));
      }
    } finally {
      notes.dispose();
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 155,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            Text(label.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(color: AppColors.grey400, fontSize: 10)),
          ]),
        ),
      );
}

String? normalizeVerificationStatus(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase().replaceAll(' ', '_');
  return const {'pending', 'verified', 'needs_changes', 'suspended'}
          .contains(value)
      ? value
      : null;
}
