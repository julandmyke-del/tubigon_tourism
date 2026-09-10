import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguWasteReportsPage extends ConsumerStatefulWidget {
  const LguWasteReportsPage({super.key});

  @override
  ConsumerState<LguWasteReportsPage> createState() => _State();
}

class _State extends ConsumerState<LguWasteReportsPage> {
  String _status = 'all';
  String _query = '';
  String _severity = 'all';
  String _category = 'all';
  String _barangay = 'all';
  bool _assignedOnly = false;
  DateTimeRange? _dates;

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(lguWasteReportsProvider);
    final all = reports.valueOrNull ?? const <Map<String, dynamic>>[];
    final categories = _values(all, 'category');
    final barangays = _values(all, 'barangay');
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Waste Management',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold)),
                    Text(
                        'Reports, assignment, resolution, and private operational mapping',
                        style: TextStyle(color: AppColors.grey400)),
                  ]),
            ),
            FilledButton.icon(
              onPressed: () => context.push('/lgu/waste-map'),
              icon: const Icon(Icons.map_rounded),
              label: const Text('Waste Map'),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _summary(
                'Submitted',
                all
                    .where((row) =>
                        ['pending', 'submitted'].contains(row['status']))
                    .length),
            _summary(
                'In Review',
                all
                    .where((row) => [
                          'under_review',
                          'assigned',
                          'in_progress',
                          'reopened'
                        ].contains(row['status']))
                    .length),
            _summary(
                'Resolved',
                all
                    .where(
                        (row) => ['resolved', 'closed'].contains(row['status']))
                    .length),
            _summary('Rejected',
                all.where((row) => row['status'] == 'rejected').length),
          ]),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search report ID, category, place, or description',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final value in const [
                'all',
                'submitted',
                'under_review',
                'assigned',
                'in_progress',
                'resolved',
                'reopened',
                'closed',
                'rejected'
              ]) ...[
                ChoiceChip(
                  label: Text(_label(value)),
                  selected: _status == value,
                  onSelected: (_) => setState(() => _status = value),
                ),
                const SizedBox(width: 6),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dropdown(
                    'Severity',
                    _severity,
                    const ['all', 'low', 'moderate', 'high', 'urgent'],
                    (value) => setState(() => _severity = value)),
                _dropdown(
                    'Category',
                    categories.contains(_category) ? _category : 'all',
                    ['all', ...categories],
                    (value) => setState(() => _category = value)),
                _dropdown(
                    'Barangay',
                    barangays.contains(_barangay) ? _barangay : 'all',
                    ['all', ...barangays],
                    (value) => setState(() => _barangay = value)),
                FilterChip(
                  label: const Text('Assigned only'),
                  selected: _assignedOnly,
                  onSelected: (value) => setState(() => _assignedOnly = value),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDates,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                      _dates == null ? 'Date range' : 'Date filter active'),
                ),
                if (_dates != null)
                  TextButton(
                      onPressed: () => setState(() => _dates = null),
                      child: const Text('Clear dates')),
              ]),
          const SizedBox(height: 12),
          Expanded(
            child: reports.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: FilledButton.icon(
                  onPressed: () => ref.invalidate(lguWasteReportsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Unable to load reports — Retry'),
                ),
              ),
              data: (items) {
                final filtered = items.where(_matches).toList(growable: false);
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No reports match these filters.',
                          style: TextStyle(color: AppColors.grey400)));
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(lguWasteReportsProvider.future),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = filtered[index];
                      final reporter = item['user'];
                      final status = item['status'] == 'pending'
                          ? 'submitted'
                          : item['status'];
                      return ListTile(
                        tileColor: const Color(0xFF1C2541),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        leading: const Icon(Icons.delete_sweep_rounded,
                            color: AppColors.warning),
                        title: Text(_label(item['category']),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${item['resolved_address'] ?? item['location_description'] ?? 'Pinned location'}\n'
                          '${reporter is Map ? reporter['name'] ?? 'Reporter' : 'Reporter'} · '
                          '${_label(status)} · ${_label(item['severity'] ?? item['priority'] ?? 'moderate')}',
                          style: const TextStyle(color: AppColors.grey400),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.grey400),
                        onTap: () =>
                            context.push('/lgu/waste-reports/${item['id']}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  bool _matches(Map<String, dynamic> item) {
    final status =
        item['status'] == 'pending' ? 'submitted' : item['status']?.toString();
    final created =
        DateTime.tryParse(item['created_at']?.toString() ?? '')?.toLocal();
    final inDates = _dates == null ||
        (created != null &&
            !created.isBefore(_dates!.start) &&
            created.isBefore(_dates!.end.add(const Duration(days: 1))));
    final haystack = '${item['id'] ?? ''} ${item['category'] ?? ''} '
            '${item['resolved_address'] ?? ''} ${item['location_description'] ?? ''} ${item['description'] ?? ''}'
        .toLowerCase();
    return (_status == 'all' || status == _status) &&
        (_severity == 'all' ||
            (item['severity'] ?? item['priority']) == _severity) &&
        (_category == 'all' || item['category'] == _category) &&
        (_barangay == 'all' || item['barangay'] == _barangay) &&
        (!_assignedOnly ||
            item['assigned_personnel']?.toString().isNotEmpty == true) &&
        inDates &&
        haystack.contains(_query);
  }

  Widget _summary(String label, int count) => Container(
        width: 130,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
        ]),
      );

  Widget _dropdown(String label, String value, List<String> values,
          ValueChanged<String> onChanged) =>
      SizedBox(
        width: 180,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(_label(item))))
              .toList(),
          onChanged: (item) => onChanged(item ?? 'all'),
        ),
      );

  Future<void> _pickDates() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dates,
    );
    if (result != null && mounted) setState(() => _dates = result);
  }

  static List<String> _values(List<Map<String, dynamic>> rows, String key) =>
      (rows
          .map((row) => row[key]?.toString())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort());

  static String _label(dynamic value) => (value?.toString() ?? 'Unknown')
      .split(RegExp('[_-]'))
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
