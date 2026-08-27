import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/lgu_providers.dart';
import '../../repositories/lgu_repository.dart';


class LguWasteReportsPage extends ConsumerStatefulWidget {
  const LguWasteReportsPage({super.key});

  @override
  ConsumerState<LguWasteReportsPage> createState() => _LguWasteReportsPageState();
}

class _LguWasteReportsPageState extends ConsumerState<LguWasteReportsPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  final List<Map<String, dynamic>> _reports = [
    {'id': '1', 'location': 'Canigao Beach Shore', 'reporter': 'Tourist User #142', 'type': 'Plastic Waste', 'status': 'Submitted', 'date': 'Aug 3, 2026', 'severity': 'High'},
    {'id': '2', 'location': 'Tubigon Wharf Area', 'reporter': 'MSME Owner #38', 'type': 'Marine Debris', 'status': 'In Progress', 'date': 'Aug 2, 2026', 'severity': 'Medium'},
    {'id': '3', 'location': 'Mangrove Eco Park Trail', 'reporter': 'Tourist User #217', 'type': 'Organic Waste', 'status': 'Resolved', 'date': 'Aug 1, 2026', 'severity': 'Low'},
    {'id': '4', 'location': 'Public Market Vicinity', 'reporter': 'Community Member', 'type': 'Mixed Waste', 'status': 'In Progress', 'date': 'Aug 1, 2026', 'severity': 'High'},
    {'id': '5', 'location': 'Sipatan Falls Pathway', 'reporter': 'Tourist User #305', 'type': 'Litter', 'status': 'Submitted', 'date': 'Jul 31, 2026', 'severity': 'Medium'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environmental Waste Reports Management',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Coordinate municipal cleanup operations, assign sanitation teams, and resolve community waste issues',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                final item = _reports[index];
                final isHigh = item['severity'] == 'High';
                final isResolved = item['status'] == 'Resolved';
                final isInProgress = item['status'] == 'In Progress';

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isHigh ? AppColors.error.withValues(alpha: 0.4) : AppColors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isHigh ? AppColors.error.withValues(alpha: 0.15) : _accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.delete_sweep_rounded,
                          color: isHigh ? AppColors.error : _accentOrange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item['location'],
                                  style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isHigh ? AppColors.error.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${item['severity']} Severity',
                                    style: TextStyle(
                                      color: isHigh ? AppColors.error : Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Type: ${item['type']} • Filed by: ${item['reporter']}', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                            Text('Date: ${item['date']}', style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isResolved
                              ? AppColors.success.withValues(alpha: 0.2)
                              : (isInProgress ? AppColors.info.withValues(alpha: 0.2) : AppColors.warning.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['status'],
                          style: TextStyle(
                            color: isResolved ? AppColors.success : (isInProgress ? AppColors.info : AppColors.warning),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: AppColors.grey400),
                        onPressed: () => _showUpdateDialog(context, item),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Update Incident Status: ${item['location']}', style: const TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Mark as In Progress', style: TextStyle(color: AppColors.info)),
              onTap: () {
                setState(() => item['status'] = 'In Progress');
                ref.read(lguRepositoryProvider).updateWasteReportStatus(item['id'], 'In Progress');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Mark as Resolved', style: TextStyle(color: AppColors.success)),
              onTap: () {
                setState(() => item['status'] = 'Resolved');
                ref.read(lguRepositoryProvider).updateWasteReportStatus(item['id'], 'Resolved');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
