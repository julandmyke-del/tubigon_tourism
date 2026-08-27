import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminActivityLogsPage extends ConsumerStatefulWidget {
  const AdminActivityLogsPage({super.key});

  @override
  ConsumerState<AdminActivityLogsPage> createState() => _AdminActivityLogsPageState();
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
                      style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: const BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () => ref.invalidate(adminActivityLogsProvider),
                  icon: const Icon(Icons.refresh_rounded, color: AdminColors.orange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Search Bar
            Container(
              decoration: AdminColors.glassDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search audit logs by action description, target resource, or user email...',
                  hintStyle: const TextStyle(color: AdminColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AdminColors.navy900,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.borderActive)),
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
                      final action = (l['action'] ?? l['description'] ?? '').toString().toLowerCase();
                      final user = (l['user_name'] ?? l['user'] ?? '').toString().toLowerCase();
                      final target = (l['target'] ?? '').toString().toLowerCase();

                      return action.contains(_searchQuery.toLowerCase()) ||
                          user.contains(_searchQuery.toLowerCase()) ||
                          target.contains(_searchQuery.toLowerCase());
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No audit logs match the search query.', style: TextStyle(color: AdminColors.textSecondary)));
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
                            DataColumn(label: Text('USER / OFFICER', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('ACTION PERFORMED', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('TARGET RESOURCE', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('CATEGORY', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('TIMESTAMP', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('IP ADDRESS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: filtered.map((l) {
                            final user = (l['user_name'] ?? l['user'] ?? 'System Admin').toString();
                            final action = (l['action'] ?? l['description'] ?? 'System Event').toString();
                            final target = (l['target'] ?? l['resource'] ?? 'System').toString();
                            final category = (l['type'] ?? l['category'] ?? 'System Audit').toString();
                            final time = (l['created_at'] ?? l['time'] ?? 'Just now').toString();
                            final ip = (l['ip_address'] ?? l['ip'] ?? '192.168.1.1').toString();

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
                                          style: const TextStyle(color: AdminColors.orange, fontWeight: FontWeight.bold, fontSize: 10),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(user, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(action, style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13))),
                                DataCell(Text(target, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AdminColors.infoBg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(category, style: const TextStyle(color: AdminColors.info, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Text(time, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12))),
                                DataCell(Text(ip, style: const TextStyle(color: AdminColors.textMuted, fontSize: 12, fontFamily: 'Monospace'))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
                  error: (err, _) => Center(child: Text('Error loading activity logs: $err', style: const TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
