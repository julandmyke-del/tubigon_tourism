import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminWasteReportsPage extends ConsumerStatefulWidget {
  const AdminWasteReportsPage({super.key});

  @override
  ConsumerState<AdminWasteReportsPage> createState() =>
      _AdminWasteReportsPageState();
}

class _AdminWasteReportsPageState extends ConsumerState<AdminWasteReportsPage> {
  String _statusFilter = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(adminWasteReportsProvider);

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waste Reports Management',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track environmental hazards, coastal plastic waste reports, and clean-up requests.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: const BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () => ref.invalidate(adminWasteReportsProvider),
                  icon: const Icon(Icons.refresh_rounded,
                      color: AdminColors.orange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Filter Controls
            Container(
              decoration: AdminColors.glassDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(
                          color: AdminColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by location or reporter name...',
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
                            borderSide: const BorderSide(
                                color: AdminColors.cardBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AdminColors.cardBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AdminColors.borderActive)),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
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
                        icon: const Icon(Icons.filter_alt_outlined,
                            color: AdminColors.textSecondary),
                        style: const TextStyle(
                            color: AdminColors.textPrimary, fontSize: 14),
                        items: [
                          'All',
                          'pending',
                          'submitted',
                          'in_progress',
                          'resolved',
                          'rejected'
                        ]
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                    s == 'All' ? 'All Reports' : _label(s))))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _statusFilter = val!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Reports Table
            Expanded(
              child: Container(
                decoration: AdminColors.glassDecoration(),
                clipBehavior: Clip.antiAlias,
                child: reportsAsync.when(
                  data: (reports) {
                    final filtered = reports.where((r) {
                      final user = r['user'] is Map
                          ? Map<String, dynamic>.from(r['user'])
                          : const <String, dynamic>{};
                      final reporter =
                          (user['name'] ?? '').toString().toLowerCase();
                      final location = (r['location_description'] ?? '')
                          .toString()
                          .toLowerCase();
                      final status = (r['status'] ?? '').toString();

                      final matchesQuery =
                          reporter.contains(_searchQuery.toLowerCase()) ||
                              location.contains(_searchQuery.toLowerCase());
                      final matchesStatus = _statusFilter == 'All' ||
                          status.toLowerCase() == _statusFilter.toLowerCase();
                      return matchesQuery && matchesStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                          child: Text(
                              'No environmental reports match the criteria.',
                              style:
                                  TextStyle(color: AdminColors.textSecondary)));
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AdminColors.navy900),
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(
                                label: Text('REPORT ID',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('REPORTER',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('LOCATION',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('CATEGORY',
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
                          rows: filtered.map((r) {
                            final reportId = r['id']?.toString() ??
                                r['uuid']?.toString() ??
                                '';
                            final code =
                                'WR-${reportId.substring(0, reportId.length > 4 ? 4 : reportId.length)}';
                            final user = r['user'] is Map
                                ? Map<String, dynamic>.from(r['user'])
                                : const <String, dynamic>{};
                            final reporter =
                                (user['name'] ?? 'Anonymous/removed user')
                                    .toString();
                            final location = (r['location_description'] ??
                                    'No location description')
                                .toString();
                            final category =
                                (r['category'] ?? 'Other').toString();
                            final status =
                                (r['status'] ?? 'pending').toString();

                            return DataRow(
                              cells: [
                                DataCell(Text(code,
                                    style: const TextStyle(
                                        color: AdminColors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                                DataCell(Text(reporter,
                                    style: const TextStyle(
                                        color: AdminColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13))),
                                DataCell(Text(location,
                                    style: const TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontSize: 13))),
                                DataCell(Text(category,
                                    style: const TextStyle(
                                        color: AdminColors.textPrimary,
                                        fontSize: 12))),
                                DataCell(_StatusBadge(status: status)),
                                DataCell(
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AdminColors.textSecondary,
                                        size: 18),
                                    color: AdminColors.navy900,
                                    onSelected: (newStatus) async {
                                      try {
                                        await ref
                                            .read(adminRepositoryProvider)
                                            .updateWasteReportStatus(
                                                reportId, newStatus);
                                        ref.invalidate(
                                            adminWasteReportsProvider);
                                        _feedback(
                                            'Waste report status updated.');
                                      } catch (_) {
                                        _feedback(
                                            'Unable to update this waste report.',
                                            error: true);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                          value: 'pending',
                                          child: Text('Set Pending',
                                              style: TextStyle(
                                                  color: AdminColors.warning))),
                                      const PopupMenuItem(
                                          value: 'submitted',
                                          child: Text('Set Submitted',
                                              style: TextStyle(
                                                  color: AdminColors
                                                      .textPrimary))),
                                      const PopupMenuItem(
                                          value: 'in_progress',
                                          child: Text('Mark In Progress',
                                              style: TextStyle(
                                                  color: AdminColors.info))),
                                      const PopupMenuItem(
                                          value: 'resolved',
                                          child: Text('Mark Resolved',
                                              style: TextStyle(
                                                  color: AdminColors.success))),
                                      const PopupMenuItem(
                                          value: 'rejected',
                                          child: Text('Reject',
                                              style: TextStyle(
                                                  color: AdminColors.danger))),
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
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AdminColors.orange)),
                  error: (err, _) => const Center(
                      child: Text(
                          'Unable to load waste reports. Use Refresh to retry.',
                          style: TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  void _feedback(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AdminColors.danger : null,
    ));
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = AdminColors.warningBg;
    Color fg = AdminColors.warning;

    if (s == 'resolved') {
      bg = AdminColors.successBg;
      fg = AdminColors.success;
    } else if (s == 'in_progress') {
      bg = AdminColors.infoBg;
      fg = AdminColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
