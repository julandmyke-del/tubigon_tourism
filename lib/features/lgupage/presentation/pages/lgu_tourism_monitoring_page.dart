import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../map/providers/map_provider.dart';
import '../../providers/lgu_providers.dart';

class LguTourismMonitoringPage extends ConsumerStatefulWidget {
  const LguTourismMonitoringPage({super.key});
  @override
  ConsumerState<LguTourismMonitoringPage> createState() => _State();
}

class _State extends ConsumerState<LguTourismMonitoringPage> {
  int _view = 0;
  String _listingFilter = 'submitted';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tourism Activity',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800)),
          const Text(
              'Municipal operational events and partner listing supervision.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.history_rounded),
                  label: Text('Operational Feed')),
              ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.fact_check_rounded),
                  label: Text('Partner Listings')),
            ],
            selected: {_view},
            onSelectionChanged: (value) => setState(() => _view = value.first),
          ),
          const SizedBox(height: 14),
          Expanded(child: _view == 0 ? _activityFeed() : _listingReview()),
        ]),
      ),
    );
  }

  Widget _activityFeed() {
    final activity = ref.watch(lguActivityProvider);
    final period = ref.watch(lguActivityPeriodProvider);
    final type = ref.watch(lguActivityTypeProvider);
    return Column(children: [
      Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search activity or destination',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Apply search',
                    onPressed: () => ref
                        .read(lguActivitySearchProvider.notifier)
                        .state = _search.text.trim(),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
                onSubmitted: (value) => ref
                    .read(lguActivitySearchProvider.notifier)
                    .state = value.trim(),
              ),
            ),
            _dropdown(
                'Period',
                period,
                const ['today', 'weekly', 'monthly', 'quarterly', 'yearly'],
                (value) =>
                    ref.read(lguActivityPeriodProvider.notifier).state = value),
            _dropdown(
                'Activity type',
                type,
                const [
                  'all',
                  'reservation',
                  'tourist_spot',
                  'msme',
                  'waste',
                  'map',
                  'emergency',
                  'announcement'
                ],
                (value) =>
                    ref.read(lguActivityTypeProvider.notifier).state = value),
          ]),
      const SizedBox(height: 12),
      Expanded(
        child: activity.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error.toString(),
            retry: () => ref.invalidate(lguActivityProvider),
          ),
          data: (data) {
            final items = (data['items'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            if (items.isEmpty) {
              return const _EmptyState(
                icon: Icons.history_toggle_off_rounded,
                message:
                    'No municipal activity matches this period and filter.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(lguActivityProvider.future),
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _ActivityCard(item: items[index]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _listingReview() {
    final listings = ref.watch(lguTourismListingsProvider(
        _listingFilter == 'all' ? null : _listingFilter));
    return Column(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final value in const [
            'all',
            'submitted',
            'approved',
            'needs_changes',
            'suspended'
          ])
            ChoiceChip(
              label: Text(_label(value)),
              selected: _listingFilter == value,
              onSelected: (_) => setState(() => _listingFilter = value),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: listings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error.toString(),
            retry: () => ref.invalidate(lguTourismListingsProvider),
          ),
          data: (items) => items.isEmpty
              ? const _EmptyState(
                  icon: Icons.tour_outlined,
                  message: 'No partner listings in this review state.')
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Material(
                      color: const Color(0xFF1C2541),
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
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
                          '${item['listing_type'] ?? 'service'} • ${item['address'] ?? 'No address'}\n${_label(item['approval_status']?.toString() ?? 'draft')}',
                          style: const TextStyle(color: AppColors.grey400),
                        ),
                        isThreeLine: true,
                        trailing: FilledButton.tonal(
                            onPressed: () => _review(item),
                            child: const Text('Review')),
                      ),
                    );
                  },
                ),
        ),
      ),
    ]);
  }

  Widget _dropdown(String label, String value, List<String> values,
          ValueChanged<String> onChanged) =>
      SizedBox(
        width: 190,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(_label(item))))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );

  Future<void> _review(Map<String, dynamic> item) async {
    var decision = 'approved';
    final notes = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Review ${item['listing_name'] ?? 'listing'}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      '${item['description'] ?? 'No description'}\n${item['latitude'] ?? '—'}, ${item['longitude'] ?? '—'}'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: decision,
                  items: const [
                    DropdownMenuItem(
                        value: 'approved', child: Text('Approve and publish')),
                    DropdownMenuItem(
                        value: 'needs_changes', child: Text('Needs changes')),
                    DropdownMenuItem(value: 'rejected', child: Text('Reject')),
                    DropdownMenuItem(
                        value: 'suspended', child: Text('Suspend')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => decision = value ?? decision),
                ),
                TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Review notes')),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save decision')),
          ],
        ),
      ),
    );
    if (!mounted || save != true) {
      notes.dispose();
      return;
    }
    if (decision != 'approved' && notes.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Review notes are required for this decision.')));
      notes.dispose();
      return;
    }
    try {
      await ref.read(lguRepositoryProvider).reviewTourismListing(
            item['id'].toString(),
            decision,
            notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(lguTourismListingsProvider);
      ref.invalidate(lguDashboardStatsProvider);
      ref.invalidate(lguActivityProvider);
      ref.invalidate(mapMarkersProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Listing review saved.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.error, content: Text(error.toString())));
      }
    } finally {
      notes.dispose();
    }
  }

  static String _label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(children: [
        const CircleAvatar(
          backgroundColor: Color(0x33F97316),
          child: Icon(Icons.bolt_rounded, color: Color(0xFFF97316), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['action']?.toString() ?? 'Municipal activity',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          Text(
              '${item['target'] ?? 'Municipal record'} • ${item['actor'] ?? 'Authorized user'}',
              style: const TextStyle(color: AppColors.grey400)),
        ])),
        Text(
            date == null
                ? '—'
                : DateFormat('MMM d\nh:mm a').format(date.toLocal()),
            textAlign: TextAlign.end,
            style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.grey500, size: 42),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey400)),
      ]));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 40),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey400)),
        TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry')),
      ]));
}
