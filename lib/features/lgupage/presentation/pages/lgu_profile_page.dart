import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../authentication/auth_provider.dart';

class LguProfilePage extends ConsumerWidget {
  const LguProfilePage({super.key});

  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final userName = auth.name ?? 'LGU Officer';
    final userEmail = auth.email ?? 'officer@tubigon.gov.ph';


    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Officer Profile',
              style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Municipal officer account information and department details',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: _accentOrange.withValues(alpha: 0.2),
                    child: const Icon(Icons.person_rounded, size: 48, color: _accentOrange),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(userName, style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(userEmail, style: const TextStyle(color: AppColors.grey400, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accentOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accentOrange.withValues(alpha: 0.4)),
                    ),
                    child: const Text('LGU Staff Officer', style: TextStyle(color: _accentOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Department Information', style: AppTypography.titleMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoRow(Icons.apartment_rounded, 'Department', 'Municipal Tourism Office'),
                  _buildInfoRow(Icons.location_on_rounded, 'Municipality', 'Tubigon, Bohol'),
                  _buildInfoRow(Icons.badge_rounded, 'Officer ID', 'LGU-TUB-2026-001'),
                  _buildInfoRow(Icons.calendar_today_rounded, 'Joined', 'January 15, 2026'),
                  _buildInfoRow(Icons.verified_rounded, 'Authorization Level', 'Full Municipal Access'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: _accentOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                Text(value, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
