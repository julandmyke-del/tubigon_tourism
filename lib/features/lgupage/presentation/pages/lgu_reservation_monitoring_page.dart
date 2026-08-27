import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class LguReservationMonitoringPage extends ConsumerStatefulWidget {
  const LguReservationMonitoringPage({super.key});

  @override
  ConsumerState<LguReservationMonitoringPage> createState() => _LguReservationMonitoringPageState();
}

class _LguReservationMonitoringPageState extends ConsumerState<LguReservationMonitoringPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  final List<Map<String, dynamic>> _reservations = [
    {'id': '1', 'tourist': 'Kim Reyes', 'spot': 'Canigao Island Day Tour', 'date': 'Aug 5, 2026', 'party': 4, 'status': 'Confirmed', 'amount': '₱2,400'},
    {'id': '2', 'tourist': 'Jake Morales', 'spot': 'Mangrove Eco Tour', 'date': 'Aug 6, 2026', 'party': 2, 'status': 'Pending', 'amount': '₱800'},
    {'id': '3', 'tourist': 'Lea Santos', 'spot': 'Bohol Heritage Walk', 'date': 'Aug 4, 2026', 'party': 6, 'status': 'Confirmed', 'amount': '₱1,800'},
    {'id': '4', 'tourist': 'Mark Villanueva', 'spot': 'Island Hopping Package', 'date': 'Aug 7, 2026', 'party': 8, 'status': 'Cancelled', 'amount': '₱6,400'},
    {'id': '5', 'tourist': 'Grace Tan', 'spot': 'Sipatan Falls Trek', 'date': 'Aug 8, 2026', 'party': 3, 'status': 'Pending', 'amount': '₱900'},
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
              'Reservation & Booking Monitoring',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Monitor tourist bookings, visitor party sizes, and municipal destination reservations',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reservations.length,
              itemBuilder: (context, index) {
                final item = _reservations[index];
                final isConfirmed = item['status'] == 'Confirmed';
                final isPending = item['status'] == 'Pending';

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
                          color: _accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: _accentOrange, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['spot'],
                              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text('Tourist: ${item['tourist']} • Party of ${item['party']}', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                            Text('Date: ${item['date']} • Fee: ${item['amount']}', style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? AppColors.success.withValues(alpha: 0.2)
                              : (isPending ? AppColors.warning.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['status'],
                          style: TextStyle(
                            color: isConfirmed ? AppColors.success : (isPending ? AppColors.warning : AppColors.error),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
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
