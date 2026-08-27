import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/lgu_providers.dart';

class LguMsmeMonitoringPage extends ConsumerStatefulWidget {
  const LguMsmeMonitoringPage({super.key});

  @override
  ConsumerState<LguMsmeMonitoringPage> createState() => _LguMsmeMonitoringPageState();
}

class _LguMsmeMonitoringPageState extends ConsumerState<LguMsmeMonitoringPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  String _filterStatus = 'All';

  final List<Map<String, dynamic>> _msmeList = [
    {'id': '1', 'name': 'Bohol Crafts & Souvenirs', 'owner': 'Maria Santos', 'type': 'Retail', 'status': 'Pending', 'submitted': 'Aug 1, 2026', 'docs': 4},
    {'id': '2', 'name': 'Island Breeze Restaurant', 'owner': 'Juan dela Cruz', 'type': 'Food & Beverage', 'status': 'Verified', 'submitted': 'Jul 28, 2026', 'docs': 6},
    {'id': '3', 'name': 'Tubigon Tricycle Cooperative', 'owner': 'Pedro Reyes', 'type': 'Transport', 'status': 'Pending', 'submitted': 'Aug 2, 2026', 'docs': 3},
    {'id': '4', 'name': 'Sea Breeze Resort', 'owner': 'Ana Gonzales', 'type': 'Accommodation', 'status': 'Rejected', 'submitted': 'Jul 25, 2026', 'docs': 2},
    {'id': '5', 'name': 'Bohol Dive Center', 'owner': 'Carlos Tan', 'type': 'Tourism Services', 'status': 'Verified', 'submitted': 'Jul 20, 2026', 'docs': 7},
    {'id': '6', 'name': 'Mangrove Tour Guides', 'owner': 'Rosa Lim', 'type': 'Tour Operator', 'status': 'Pending', 'submitted': 'Aug 3, 2026', 'docs': 5},
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _msmeList.where((item) {
      if (_filterStatus == 'All') return true;
      return item['status'] == _filterStatus;
    }).toList();

    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MSME Business Verification',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Review municipal business permits, verify local MSMEs, and issue tourism compliance credentials',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),

            // Status Filter Chips
            Row(
              children: ['All', 'Pending', 'Verified', 'Rejected'].map((status) {
                final isSelected = _filterStatus == status;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    selectedColor: _accentOrange,
                    backgroundColor: _cardBg,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.grey300,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _filterStatus = status),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Business Cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                final status = item['status'];
                final isPending = status == 'Pending';
                final isVerified = status == 'Verified';

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? AppColors.success.withValues(alpha: 0.15)
                              : (isPending ? AppColors.warning.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: isVerified ? AppColors.success : (isPending ? AppColors.warning : AppColors.error),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text('Owner: ${item['owner']} • Category: ${item['type']}', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                            Text('Submitted: ${item['submitted']} • ${item['docs']} documents attached', style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? AppColors.success.withValues(alpha: 0.2)
                              : (isPending ? AppColors.warning.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: isVerified ? AppColors.success : (isPending ? AppColors.warning : AppColors.error),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentOrange,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showVerifyModal(context, item),
                        child: const Text('Review', style: TextStyle(fontSize: 12)),
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

  void _showVerifyModal(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Review ${item['name']}', style: const TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner: ${item['owner']}', style: const TextStyle(color: AppColors.grey300)),
            Text('Category: ${item['type']}', style: const TextStyle(color: AppColors.grey300)),
            Text('Documents: ${item['docs']} files verified', style: const TextStyle(color: AppColors.grey400)),
            const SizedBox(height: 16),
            const Text('Action:', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => item['status'] = 'Rejected');
              ref.read(lguRepositoryProvider).verifyMsme(item['id'], false, status: 'Rejected');
              Navigator.pop(context);
            },
            child: const Text('Reject', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              setState(() => item['status'] = 'Verified');
              ref.read(lguRepositoryProvider).verifyMsme(item['id'], true, status: 'Verified');
              Navigator.pop(context);
            },
            child: const Text('Approve & Verify', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }
}
