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
  String? _settingsId;

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
        _settingsId = settings['id']?.toString();
        _nameCtrl.text = settings['app_name'] as String? ?? '';
        _emailCtrl.text = settings['contact_email'] as String? ?? '';
        _phoneCtrl.text = settings['contact_phone'] as String? ?? '';
        _privacyCtrl.text = settings['privacy_policy'] as String? ?? '';
        _termsCtrl.text = settings['terms_of_service'] as String? ?? '';
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
                      style: AppTypography.bodyMedium
                          .copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _saving ? null : _saveSettings,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Saving...' : 'Save Settings',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        const Text('General Platform Details',
                            style: TextStyle(
                                color: AdminColors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: AppSpacing.md),
                        _buildInputField(
                            'System Name', _nameCtrl, Icons.apps_rounded),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                                child: _buildInputField(
                                    'Municipal Contact Email',
                                    _emailCtrl,
                                    Icons.email_outlined)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                                child: _buildInputField('Hotline Phone Number',
                                    _phoneCtrl, Icons.phone_outlined)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(color: AdminColors.cardBorder),
                        const SizedBox(height: AppSpacing.md),
                        const Text('Municipal Terms & Privacy Policy Text',
                            style: TextStyle(
                                color: AdminColors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: AppSpacing.md),
                        _buildInputField('Privacy Policy Summary', _privacyCtrl,
                            Icons.shield_outlined,
                            maxLines: 3),
                        const SizedBox(height: AppSpacing.md),
                        _buildInputField('Terms of Service Summary', _termsCtrl,
                            Icons.description_outlined,
                            maxLines: 3),
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

  Widget _buildInputField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AdminColors.textSecondary, size: 18),
            filled: true,
            fillColor: AdminColors.navy900,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AdminColors.cardBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AdminColors.cardBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AdminColors.borderActive)),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty && maxLines == 1) return '$label is required.';
            if (label.contains('Email') && !text.contains('@')) {
              return 'Enter a valid contact email.';
            }
            return null;
          },
        ),
      ],
    );
  }

  void _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final settingsId = _settingsId;
    if (settingsId == null || settingsId.isEmpty) {
      _message('Unable to save because the system settings record is missing.',
          error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).updateSystemSettings({
        'app_name': _nameCtrl.text.trim(),
        'contact_email': _emailCtrl.text.trim(),
        'contact_phone': _phoneCtrl.text.trim(),
        'privacy_policy': _privacyCtrl.text.trim(),
        'terms_of_service': _termsCtrl.text.trim(),
      }, settingsId);
      ref.invalidate(adminSettingsProvider);
      _message('System settings updated.');
    } catch (_) {
      _message('Unable to update system settings.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error ? AdminColors.danger : AdminColors.success,
      content: Text(value),
    ));
  }
}
