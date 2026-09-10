import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminActivityLogsPage extends ConsumerStatefulWidget {
  const AdminActivityLogsPage({super.key});

  @override
  ConsumerState<AdminActivityLogsPage> createState() =>
      _AdminActivityLogsPageState();
}

class _AdminActivityLogsPageState extends ConsumerState<AdminActivityLogsPage> {
  final _search = TextEditingController();
  final _action = TextEditingController();
  String? _role;
  DateTimeRange? _dates;
  int _page = 1;
  String? _appliedSearch;
  String? _appliedAction;

  @override
  void dispose() {
    _search.dispose();
    _action.dispose();
    super.dispose();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  AdminActivityLogQuery get _query => AdminActivityLogQuery(
        page: _page,
        role: _role,
        action: _appliedAction,
        search: _appliedSearch,
        dateFrom: _dates == null ? null : _date(_dates!.start),
        dateTo: _dates == null ? null : _date(_dates!.end),
      );

  void _apply() => setState(() {
        _page = 1;
        _appliedSearch =
            _search.text.trim().isEmpty ? null : _search.text.trim();
        _appliedAction =
            _action.text.trim().isEmpty ? null : _action.text.trim();
      });

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dates,
    );
    if (range != null && mounted) {
      setState(() {
        _dates = range;
        _page = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final logsAsync = ref.watch(adminActivityLogsProvider(query));

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('System Activity Audit Logs',
                      style: AppTypography.headlineMedium.copyWith(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      'Role-aware, searchable history of meaningful system actions.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AdminColors.textSecondary)),
                ])),
            IconButton(
              tooltip: 'Refresh logs',
              onPressed: () => ref.invalidate(adminActivityLogsProvider(query)),
              icon:
                  const Icon(Icons.refresh_rounded, color: AdminColors.orange),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: AdminColors.glassDecoration(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                      width: 290,
                      child: TextField(
                        controller: _search,
                        onSubmitted: (_) => _apply(),
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Actor, action, target, or details'),
                      )),
                  SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration:
                            const InputDecoration(labelText: 'Actor role'),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All roles')),
                          DropdownMenuItem(
                              value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(
                              value: 'lgu_staff', child: Text('LGU Staff')),
                          DropdownMenuItem(
                              value: 'tourism_partner',
                              child: Text('Tourism Partner')),
                          DropdownMenuItem(
                              value: 'msme_owner', child: Text('MSME Owner')),
                          DropdownMenuItem(
                              value: 'tourist', child: Text('Tourist')),
                        ],
                        onChanged: (value) => setState(() {
                          _role = value?.isEmpty == true ? null : value;
                          _page = 1;
                        }),
                      )),
                  SizedBox(
                      width: 230,
                      child: TextField(
                        controller: _action,
                        onSubmitted: (_) => _apply(),
                        decoration: const InputDecoration(
                            labelText: 'Action type',
                            hintText: 'profile_updated'),
                      )),
                  OutlinedButton.icon(
                      onPressed: _pickDates,
                      icon: const Icon(Icons.date_range),
                      label: Text(_dates == null
                          ? 'Date range'
                          : '${_date(_dates!.start)} – ${_date(_dates!.end)}')),
                  FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.filter_alt),
                      label: const Text('Apply')),
                  if (_dates != null ||
                      _role != null ||
                      _appliedSearch != null ||
                      _appliedAction != null)
                    TextButton(
                        onPressed: () => setState(() {
                              _dates = null;
                              _role = null;
                              _page = 1;
                              _appliedSearch = null;
                              _appliedAction = null;
                              _search.clear();
                              _action.clear();
                            }),
                        child: const Text('Clear filters')),
                ]),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
              child: Container(
            decoration: AdminColors.glassDecoration(),
            clipBehavior: Clip.antiAlias,
            child: logsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AdminColors.orange)),
              error: (error, _) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline,
                    color: AdminColors.danger, size: 42),
                const SizedBox(height: 12),
                const Text('Unable to load activity logs.',
                    style: TextStyle(color: AdminColors.textSecondary)),
                TextButton(
                    onPressed: () =>
                        ref.invalidate(adminActivityLogsProvider(query)),
                    child: const Text('Retry')),
              ])),
              data: (pageData) {
                final rows = (pageData['data'] as List? ?? const [])
                    .whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .toList();
                final current =
                    int.tryParse('${pageData['current_page']}') ?? _page;
                final last = int.tryParse('${pageData['last_page']}') ?? 1;
                final total =
                    int.tryParse('${pageData['total']}') ?? rows.length;
                if (rows.isEmpty) {
                  return const Center(
                      child: Text('No activity matches these filters.',
                          style: TextStyle(color: AdminColors.textSecondary)));
                }
                return Column(children: [
                  Expanded(
                      child: SingleChildScrollView(
                          child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(AdminColors.navy900),
                      columns: const [
                        DataColumn(label: Text('ACTOR / ROLE')),
                        DataColumn(label: Text('ACTION')),
                        DataColumn(label: Text('TARGET')),
                        DataColumn(label: Text('DETAILS')),
                        DataColumn(label: Text('TIMESTAMP')),
                      ],
                      rows: rows.map((log) {
                        final actor = log['user'] is Map
                            ? Map<String, dynamic>.from(log['user'])
                            : const <String, dynamic>{};
                        final name =
                            actor['name']?.toString() ?? 'Removed user';
                        final role = log['actor_role']?.toString() ??
                            (actor['role'] is Map
                                ? actor['role']['name']?.toString()
                                : null) ??
                            'role unavailable';
                        final target = [log['target_type'], log['target_id']]
                            .where((value) =>
                                value != null && value.toString().isNotEmpty)
                            .join(' · ');
                        return DataRow(cells: [
                          DataCell(SizedBox(
                              width: 180,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name),
                                    Text(role.replaceAll('_', ' '),
                                        style: const TextStyle(
                                            color: AdminColors.orange,
                                            fontSize: 11))
                                  ]))),
                          DataCell(SizedBox(
                              width: 220,
                              child: Text(log['action']?.toString() ??
                                  'System event'))),
                          DataCell(SizedBox(
                              width: 210,
                              child: Text(target.isEmpty ? '—' : target))),
                          DataCell(SizedBox(
                              width: 330,
                              child: Text(log['details']?.toString() ?? '—',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis))),
                          DataCell(Text(log['created_at']?.toString() ?? '—')),
                        ]);
                      }).toList(),
                    ),
                  ))),
                  Container(
                      color: AdminColors.navy900,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Text('$total records · Page $current of $last',
                            style: const TextStyle(
                                color: AdminColors.textSecondary)),
                        const Spacer(),
                        IconButton(
                            onPressed: current > 1
                                ? () => setState(() => _page = current - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left)),
                        IconButton(
                            onPressed: current < last
                                ? () => setState(() => _page = current + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right)),
                      ])),
                ]);
              },
            ),
          )),
        ]),
      ),
    );
  }
}
