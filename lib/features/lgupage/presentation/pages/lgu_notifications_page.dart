import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class LguNotificationsPage extends ConsumerWidget {
  const LguNotificationsPage({super.key});

  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = [
      {'type': 'msme', 'message': 'New MSME verification request from Bohol Crafts & Souvenirs', 'time': '5 min ago', 'read': false, 'icon': Icons.storefront_rounded, 'color': _accentOrange},
      {'type': 'waste', 'message': 'High severity waste report at Canigao Beach Shore', 'time': '12 min ago', 'read': false, 'icon': Icons.delete_sweep_rounded, 'color': AppColors.error},
      {'type': 'review', 'message': 'Community review flagged for moderation at Tubigon Market', 'time': '1 hr ago', 'read': false, 'icon': Icons.rate_review_rounded, 'color': Colors.purpleAccent},
      {'type': 'reservation', 'message': 'Reservation #004 cancelled — Island Hopping Package', 'time': '2 hr ago', 'read': true, 'icon': Icons.calendar_month_rounded, 'color': AppColors.warning},
      {'type': 'announcement', 'message': 'Draft "Updated Ferry Schedules" ready for review', 'time': '3 hr ago', 'read': true, 'icon': Icons.campaign_rounded, 'color': AppColors.info},
      {'type': 'system', 'message': 'Monthly tourism report for July 2026 ready for download', 'time': '5 hr ago', 'read': true, 'icon': Icons.assessment_rounded, 'color': AppColors.grey400},
    ];

    final unreadCount = notifications.where((n) => n['read'] == false).length;

    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Center',
                      style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$unreadCount unread municipal notifications',
                      style: const TextStyle(color: AppColors.grey400, fontSize: 13),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Mark all as read', style: TextStyle(color: _accentOrange)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                final isRead = item['read'] as bool;
                final color = item['color'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isRead ? _cardBg : _cardBg.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isRead ? AppColors.white.withValues(alpha: 0.06) : color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item['icon'] as IconData, color: color, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['message'] as String,
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(item['time'] as String, style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: _accentOrange, shape: BoxShape.circle),
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
}
