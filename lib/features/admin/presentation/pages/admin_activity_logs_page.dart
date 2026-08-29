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
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(adminActivityLogsProvider);

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
                      'System Activity Audit Logs',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time security audit log, administrative actions, and system event history.',
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
                  onPressed: () => ref.invalidate(adminActivityLogsProvider),
                  icon: const Icon(Icons.refresh_rounded,
                      color: AdminColors.orange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Search Bar
            Container(
              decoration: AdminColors.glassDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                style: const TextStyle(
                    color: AdminColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'Search audit logs by action description, target resource, or user email...',
                  hintStyle: const TextStyle(color: AdminColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AdminColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AdminColors.navy900,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AdminColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AdminColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AdminColors.borderActive)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Logs Table
            Expanded(
              child: Container(
                decoration: AdminColors.glassDecoration(),
                clipBehavior: Clip.antiAlias,
                child: logsAsync.when(
                  data: (logs) {
                    final filtered = logs.where((l) {
                      final action = (l['action'] ?? l['description'] ?? '')
                          .toString()
                          .toLowerCase();
                      final userData = l['user'] is Map
                          ? Map<String, dynamic>.from(l['user'])
                          : const <String, dynamic>{};
                      final user =
                          (userData['name'] ?? '').toString().toLowerCase();
                      final details =
                          (l['details'] ?? '').toString().toLowerCase();

                      return action.contains(_searchQuery.toLowerCase()) ||
                          user.contains(_searchQuery.toLowerCase()) ||
                          details.contains(_searchQuery.toLowerCase());
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                          child: Text('No audit logs match the search query.',
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
                                label: Text('USER / OFFICER',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('ACTION PERFORMED',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('DETAILS',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('TIMESTAMP',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                          ],
                          rows: filtered.map((l) {
                            final userData = l['user'] is Map
                                ? Map<String, dynamic>.from(l['user'])
                                : const <String, dynamic>{};
                            final user =
                                (userData['name'] ?? 'Unknown/removed user')
                                    .toString();
                            final action = (l['action'] ?? '').toString();
                            final details = (l['details'] ?? '').toString();
                            final time = (l['created_at'] ?? '').toString();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AdminColors.orangeDim,
                                        child: Text(
                                          user.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                              color: AdminColors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(user,
                                          style: const TextStyle(
                                              color: AdminColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(action,
                                    style: const TextStyle(
                                        color: AdminColors.textPrimary,
                                        fontSize: 13))),
                                DataCell(SizedBox(
                                    width: 360,
                                    child: Text(details,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AdminColors.textSecondary,
                                            fontSize: 13)))),
                                DataCell(Text(time,
                                    style: const TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontSize: 12))),
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
                          'Unable to load activity logs. Use Refresh to retry.',
                          style: TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
