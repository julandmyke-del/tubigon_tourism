import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../authentication/auth_provider.dart';

class LguSettingsPage extends ConsumerStatefulWidget {
  const LguSettingsPage({super.key});

  @override
  ConsumerState<LguSettingsPage> createState() => _LguSettingsPageState();
}

class _LguSettingsPageState extends ConsumerState<LguSettingsPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  bool _pushNotifications = true;
  bool _emailAlerts = false;
  bool _wasteAlerts = true;
  bool _msmeAlerts = true;

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
              'System Settings',
              style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Configure platform preferences, notification channels, and account security',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Notification Settings
            _buildSettingsSection('Notification Preferences', [
              _buildSwitchTile(Icons.notifications_rounded, 'Push Notifications', 'Real-time municipal alerts on device', _pushNotifications, (val) => setState(() => _pushNotifications = val)),
              _buildSwitchTile(Icons.email_rounded, 'Email Alerts', 'Receive daily digest to official email', _emailAlerts, (val) => setState(() => _emailAlerts = val)),
              _buildSwitchTile(Icons.delete_sweep_rounded, 'Waste Report Alerts', 'Notify on new environmental incidents', _wasteAlerts, (val) => setState(() => _wasteAlerts = val)),
              _buildSwitchTile(Icons.storefront_rounded, 'MSME Verification Alerts', 'Notify on new business applications', _msmeAlerts, (val) => setState(() => _msmeAlerts = val)),
            ]),
            const SizedBox(height: AppSpacing.md),

            // Account Settings
            _buildSettingsSection('Account & Security', [
              _buildActionTile(Icons.lock_rounded, 'Change Password', 'Update your officer account password', () {}),
              _buildActionTile(Icons.security_rounded, 'Two-Factor Authentication', 'Secure your LGU staff account', () {}),
              _buildActionTile(Icons.devices_rounded, 'Active Sessions', 'Manage logged-in devices and sessions', () {}),
            ]),
            const SizedBox(height: AppSpacing.md),

            // Danger Zone
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session', style: AppTypography.titleMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out of LGU Portal'),
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/onboarding?page=5&login=true');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Icon(icon, color: _accentOrange, size: 22),
      title: Text(title, style: const TextStyle(color: AppColors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
      trailing: Switch(
        value: value,
        activeColor: _accentOrange,
        activeTrackColor: _accentOrange.withValues(alpha: 0.3),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.grey300, size: 22),
      title: Text(title, style: const TextStyle(color: AppColors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
      onTap: onTap,
    );
  }
}
