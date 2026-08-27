import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _privacyCtrl;
  late TextEditingController _termsCtrl;
  bool _initialized = false;
  bool _saving = false;
  bool _requireVerification = true;
  bool _maintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _privacyCtrl = TextEditingController();
    _termsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _privacyCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminSettingsProvider);

    settingsAsync.whenData((settings) {
      if (!_initialized) {
        _nameCtrl.text = settings['app_name'] as String? ?? 'Tubigon Smart Tourism & Information System';
        _emailCtrl.text = settings['contact_email'] as String? ?? 'support@tubigontourism.gov.ph';
        _phoneCtrl.text = settings['contact_phone'] as String? ?? '+63 38 508 8000';
        _privacyCtrl.text = settings['privacy_policy'] as String? ?? 'Standard Municipal Privacy Guidelines.';
        _termsCtrl.text = settings['terms_of_service'] as String? ?? 'Standard Terms of Service for Tubigon Tourism Portal.';
        _initialized = true;
      }
    });

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
                      'System Settings',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure municipal platform details, security switches, and contact information.',
                      style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _saving ? null : _saveSettings,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Saving...' : 'Save Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  decoration: AdminColors.glassDecoration(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('General Platform Details', style: TextStyle(color: AdminColors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: AppSpacing.md),
                        _buildInputField('System Name', _nameCtrl, Icons.apps_rounded),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(child: _buildInputField('Municipal Contact Email', _emailCtrl, Icons.email_outlined)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: _buildInputField('Hotline Phone Number', _phoneCtrl, Icons.phone_outlined)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(color: AdminColors.cardBorder),
                        const SizedBox(height: AppSpacing.md),

                        const Text('System Security & Governance Switches', style: TextStyle(color: AdminColors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: AppSpacing.sm),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AdminColors.orange,
                          activeTrackColor: AdminColors.orangeDim,
                          inactiveTrackColor: AdminColors.navy900,
                          title: const Text('Require User Email Verification', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Enforce email validation before granting tourist profile privileges', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
                          value: _requireVerification,
                          onChanged: (val) => setState(() => _requireVerification = val),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AdminColors.orange,
                          activeTrackColor: AdminColors.orangeDim,
                          inactiveTrackColor: AdminColors.navy900,
                          title: const Text('System Maintenance Mode', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Temporarily restrict public access during scheduled server maintenance', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
                          value: _maintenanceMode,
                          onChanged: (val) => setState(() => _maintenanceMode = val),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(color: AdminColors.cardBorder),
                        const SizedBox(height: AppSpacing.md),

                        const Text('Municipal Terms & Privacy Policy Text', style: TextStyle(color: AdminColors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: AppSpacing.md),
                        _buildInputField('Privacy Policy Summary', _privacyCtrl, Icons.shield_outlined, maxLines: 3),
                        const SizedBox(height: AppSpacing.md),
                        _buildInputField('Terms of Service Summary', _termsCtrl, Icons.description_outlined, maxLines: 3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AdminColors.textSecondary, size: 18),
            filled: true,
            fillColor: AdminColors.navy900,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.borderActive)),
          ),
        ),
      ],
    );
  }

  void _saveSettings() async {
    setState(() => _saving = true);
    final repo = ref.read(adminRepositoryProvider);
    final success = await repo.updateSystemSettings({
      'app_name': _nameCtrl.text.trim(),
      'contact_email': _emailCtrl.text.trim(),
      'contact_phone': _phoneCtrl.text.trim(),
      'privacy_policy': _privacyCtrl.text.trim(),
      'terms_of_service': _termsCtrl.text.trim(),
    });
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? AdminColors.success : AdminColors.danger,
          content: Text(success ? 'System settings updated successfully!' : 'Failed to update settings.'),
        ),
      );
    }
  }
}
