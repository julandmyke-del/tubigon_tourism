import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminWasteReportsPage extends ConsumerStatefulWidget {
  const AdminWasteReportsPage({super.key});

  @override
  ConsumerState<AdminWasteReportsPage> createState() => _AdminWasteReportsPageState();
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
                      style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: const BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () => ref.invalidate(adminWasteReportsProvider),
                  icon: const Icon(Icons.refresh_rounded, color: AdminColors.orange),
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
                      style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by location or reporter name...',
                        hintStyle: const TextStyle(color: AdminColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AdminColors.navy900,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.borderActive)),
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
                        icon: const Icon(Icons.filter_alt_outlined, color: AdminColors.textSecondary),
                        style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                        items: ['All', 'Pending', 'In Progress', 'Resolved']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Reports' : s)))
                            .toList(),
                        onChanged: (val) => setState(() => _statusFilter = val!),
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
                      final reporter = (r['user_name'] ?? r['reporter'] ?? '').toString().toLowerCase();
                      final location = (r['location'] ?? r['address'] ?? '').toString().toLowerCase();
                      final status = (r['status'] ?? 'Pending').toString();

                      final matchesQuery = reporter.contains(_searchQuery.toLowerCase()) || location.contains(_searchQuery.toLowerCase());
                      final matchesStatus = _statusFilter == 'All' || status.toLowerCase() == _statusFilter.toLowerCase();
                      return matchesQuery && matchesStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No environmental reports match the criteria.', style: TextStyle(color: AdminColors.textSecondary)));
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AdminColors.navy900),
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('REPORT ID', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('REPORTER', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('LOCATION', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('SEVERITY', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('STATUS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: filtered.map((r) {
                            final reportId = r['id']?.toString() ?? r['uuid']?.toString() ?? '';
                            final code = 'WR-${reportId.substring(0, reportId.length > 4 ? 4 : reportId.length)}';
                            final reporter = (r['user_name'] ?? r['reporter'] ?? 'Citizen').toString();
                            final location = (r['location'] ?? r['address'] ?? 'Port Area').toString();
                            final severity = (r['severity'] ?? 'Medium').toString();
                            final status = (r['status'] ?? 'Pending').toString();

                            return DataRow(
                              cells: [
                                DataCell(Text(code, style: const TextStyle(color: AdminColors.orange, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataCell(Text(reporter, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                                DataCell(Text(location, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13))),
                                DataCell(_SeverityBadge(severity: severity)),
                                DataCell(_StatusBadge(status: status)),
                                DataCell(
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.edit_outlined, color: AdminColors.textSecondary, size: 18),
                                    color: AdminColors.navy900,
                                    onSelected: (newStatus) async {
                                      final repo = ref.read(adminRepositoryProvider);
                                      await repo.updateWasteReportStatus(reportId, newStatus);
                                      ref.invalidate(adminWasteReportsProvider);
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'Pending', child: Text('Set Pending', style: TextStyle(color: AdminColors.warning))),
                                      const PopupMenuItem(value: 'In Progress', child: Text('Mark In Progress', style: TextStyle(color: AdminColors.info))),
                                      const PopupMenuItem(value: 'Resolved', child: Text('Mark Resolved', style: TextStyle(color: AdminColors.success))),
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
                  loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final s = severity.toLowerCase();
    Color bg = AdminColors.infoBg;
    Color fg = AdminColors.info;

    if (s == 'high' || s == 'critical') {
      bg = AdminColors.dangerBg;
      fg = AdminColors.danger;
    } else if (s == 'medium') {
      bg = AdminColors.warningBg;
      fg = AdminColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
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
    } else if (s == 'in progress') {
      bg = AdminColors.infoBg;
      fg = AdminColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
