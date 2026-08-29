import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';
import '../../../map/providers/map_provider.dart';
import '../../../msmepage/repositories/msme_repository.dart';

class AdminMsmeManagementPage extends ConsumerStatefulWidget {
  const AdminMsmeManagementPage({super.key});

  @override
  ConsumerState<AdminMsmeManagementPage> createState() =>
      _AdminMsmeManagementPageState();
}

class _AdminMsmeManagementPageState
    extends ConsumerState<AdminMsmeManagementPage> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final msmesAsync = ref.watch(adminMsmesProvider);

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
                      'MSME Management',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review, verify, approve, or suspend local merchant registrations and business profiles.',
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
                  onPressed: () => ref.invalidate(adminMsmesProvider),
                  icon: const Icon(Icons.refresh_rounded,
                      color: AdminColors.orange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Search & Status Filters
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
                        hintText: 'Search by MSME name, category, or owner...',
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
                          borderSide:
                              const BorderSide(color: AdminColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AdminColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AdminColors.borderActive),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
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
                        icon: const Icon(Icons.filter_list_rounded,
                            color: AdminColors.textSecondary),
                        style: const TextStyle(
                            color: AdminColors.textPrimary, fontSize: 14),
                        items: ['All', 'Verified', 'Unverified']
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s == 'All' ? 'All Statuses' : s)))
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

            // MSME Table
            Expanded(
              child: Container(
                decoration: AdminColors.glassDecoration(),
                clipBehavior: Clip.antiAlias,
                child: msmesAsync.when(
                  data: (msmes) {
                    final filtered = msmes.where((m) {
                      final name = (m['name'] ?? m['business_name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final category = (m['category'] ?? m['type'] ?? '')
                          .toString()
                          .toLowerCase();
                      final profile = m['profile'] is Map
                          ? Map<String, dynamic>.from(m['profile'])
                          : const <String, dynamic>{};
                      final owner =
                          (profile['name'] ?? '').toString().toLowerCase();
                      final status =
                          m['is_verified'] == true ? 'Verified' : 'Unverified';

                      final matchesQuery =
                          name.contains(_searchQuery.toLowerCase()) ||
                              category.contains(_searchQuery.toLowerCase()) ||
                              owner.contains(_searchQuery.toLowerCase());
                      final matchesStatus = _statusFilter == 'All' ||
                          status.toLowerCase() == _statusFilter.toLowerCase();
                      return matchesQuery && matchesStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                            'No MSMEs match the search and filter criteria.',
                            style: TextStyle(color: AdminColors.textSecondary)),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AdminColors.navy900),
                          dataRowColor:
                              WidgetStateProperty.all(Colors.transparent),
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(
                                label: Text('BUSINESS NAME',
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
                                label: Text('OWNER',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('RATING',
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
                          rows: filtered.map((m) {
                            final msmeId = m['id']?.toString() ??
                                m['uuid']?.toString() ??
                                '';
                            final name = (m['name'] ??
                                    m['business_name'] ??
                                    'MSME Business')
                                .toString();
                            final category =
                                (m['category'] ?? m['type'] ?? 'General')
                                    .toString();
                            final profile = m['profile'] is Map
                                ? Map<String, dynamic>.from(m['profile'])
                                : const <String, dynamic>{};
                            final owner = (profile['name'] ?? 'No linked owner')
                                .toString();
                            final rating =
                                (m['rating'] as num?)?.toDouble() ?? 0;
                            final status = m['is_verified'] == true
                                ? 'Verified'
                                : 'Unverified';

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AdminColors.purpleBg,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.store_rounded,
                                            color: AdminColors.purple,
                                            size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(name,
                                          style: const TextStyle(
                                              color: AdminColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AdminColors.infoBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(category,
                                        style: const TextStyle(
                                            color: AdminColors.info,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Text(owner,
                                    style: const TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontSize: 13))),
                                DataCell(
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                              color: AdminColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                DataCell(_StatusBadge(status: status)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.check_circle_outline_rounded,
                                            color: AdminColors.success,
                                            size: 18),
                                        tooltip: 'Verify MSME',
                                        onPressed: () =>
                                            _updateMsmeStatus(msmeId, true),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.block_rounded,
                                            color: AdminColors.warning,
                                            size: 18),
                                        tooltip: 'Remove MSME verification',
                                        onPressed: () =>
                                            _updateMsmeStatus(msmeId, false),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AdminColors.danger,
                                            size: 18),
                                        tooltip: 'Archive MSME',
                                        onPressed: () =>
                                            _confirmDeleteMsme(msmeId, name),
                                      ),
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
                      child: Text('Unable to load MSMEs. Use Refresh to retry.',
                          style: TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMsmeStatus(String id, bool verified) async {
    try {
      await ref.read(adminRepositoryProvider).updateMsmeStatus(id, verified);
      _invalidateMsmeSurfaces();
      _feedback(verified ? 'MSME verified.' : 'MSME verification removed.');
    } catch (_) {
      _feedback('Unable to update this MSME.', error: true);
    }
  }

  void _confirmDeleteMsme(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('Archive MSME',
            style: TextStyle(color: AdminColors.textPrimary)),
        content: Text('Archive the MSME registration for "$name"?',
            style: const TextStyle(color: AdminColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () async {
              try {
                await ref.read(adminRepositoryProvider).deleteMsme(id);
                _invalidateMsmeSurfaces();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _feedback('MSME archived.');
              } catch (_) {
                _feedback('Unable to archive this MSME.', error: true);
              }
            },
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _invalidateMsmeSurfaces() {
    ref.invalidate(adminMsmesProvider);
    ref.invalidate(msmeListProvider);
    ref.invalidate(mapMarkersProvider);
  }

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

    if (s == 'verified') {
      bg = AdminColors.successBg;
      fg = AdminColors.success;
    } else if (s == 'unverified') {
      bg = AdminColors.dangerBg;
      fg = AdminColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
