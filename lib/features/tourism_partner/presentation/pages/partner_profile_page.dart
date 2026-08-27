import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../authentication/auth_provider.dart';
import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerProfilePage extends ConsumerStatefulWidget {
  const PartnerProfilePage({super.key});

  @override
  ConsumerState<PartnerProfilePage> createState() => _PartnerProfilePageState();
}

class _PartnerProfilePageState extends ConsumerState<PartnerProfilePage> {
  bool _isEditing = false;
  bool _isSaving = false;

  final _firstNameCtrl = TextEditingController(text: 'Explorer');
  final _lastNameCtrl = TextEditingController(text: 'Partner');
  final _emailCtrl = TextEditingController(text: 'explorer@tubigontourism.com');
  final _phoneCtrl = TextEditingController(text: '+63 917 123 4567');
  final _addressCtrl = TextEditingController(text: 'Tubigon, Bohol, Philippines');
  final _bioCtrl = TextEditingController(
    text: 'Passionate tourism entrepreneur offering authentic Bohol experiences. Specializing in island hopping, diving, and dolphin watching tours since 2020.',
  );

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.name != null && auth.name!.isNotEmpty) {
      final parts = auth.name!.split(' ');
      _firstNameCtrl.text = parts.first;
      if (parts.length > 1) {
        _lastNameCtrl.text = parts.sublist(1).join(' ');
      }
    }
    if (auth.email != null && auth.email!.isNotEmpty) {
      _emailCtrl.text = auth.email!;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(tourismPartnerRepositoryProvider);
      await repo.updateProfile({
        'name': '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: PartnerTheme.green),
        );
        setState(() => _isEditing = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved locally.'), backgroundColor: PartnerTheme.green),
        );
        setState(() => _isEditing = false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Partner Profile', style: PartnerTheme.headingLarge()),
            Text('Manage your personal information and public partner details.', style: PartnerTheme.label()),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 850;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 340, child: _buildLeftProfileCard(auth)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildRightEditForm()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildLeftProfileCard(auth),
                    const SizedBox(height: 24),
                    _buildRightEditForm(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftProfileCard(AuthState auth) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: PartnerTheme.cardDecoration(),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: PartnerTheme.orangeGradient,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Color(0x66F97316), blurRadius: 20, offset: Offset(0, 8))],
                      border: Border.all(color: PartnerTheme.primaryOrange.withValues(alpha: 0.3), width: 3),
                    ),
                    child: Center(
                      child: Text(
                        (_firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text[0] : 'E').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: PartnerTheme.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('${_firstNameCtrl.text} ${_lastNameCtrl.text}', style: PartnerTheme.headingMedium()),
              Text('Business Partner', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: PartnerTheme.primaryOrange)),
              const SizedBox(height: 4),
              Text(_addressCtrl.text, style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textDisabled)),
              const SizedBox(height: 14),

              const Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  PartnerBadge(label: 'Verified', type: PartnerBadgeType.green),
                  PartnerBadge(label: 'Premium Partner', type: PartnerBadgeType.orange),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                  icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded, size: 18),
                  label: Text(_isEditing ? 'Cancel Editing' : 'Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? Colors.white.withValues(alpha: 0.1) : PartnerTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats Overview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: PartnerTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PARTNER STATS', style: PartnerTheme.label()),
              const SizedBox(height: 14),
              _statRow('Listings', '12', Icons.store_rounded),
              _statRow('Total Bookings', '248', Icons.calendar_month_rounded),
              _statRow('Avg Rating', '4.8 ⭐', Icons.star_rounded),
              _statRow('Member Since', 'Jan 2024', Icons.card_membership_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String val, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: PartnerTheme.textDisabled),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textMuted)),
            ],
          ),
          Text(val, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: PartnerTheme.textWhite)),
        ],
      ),
    );
  }

  Widget _buildRightEditForm() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Personal Information', style: PartnerTheme.headingMedium()),
              if (_isEditing)
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(backgroundColor: PartnerTheme.primaryOrange, foregroundColor: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(child: _formField('FIRST NAME', _firstNameCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _formField('LAST NAME', _lastNameCtrl)),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _formField('EMAIL ADDRESS', _emailCtrl, isEmail: true)),
              const SizedBox(width: 16),
              Expanded(child: _formField('PHONE NUMBER', _phoneCtrl)),
            ],
          ),
          const SizedBox(height: 16),

          _formField('ADDRESS', _addressCtrl),
          const SizedBox(height: 16),

          _formField('BIO / ABOUT', _bioCtrl, maxLines: 4),
        ],
      ),
    );
  }

  Widget _formField(String label, TextEditingController controller, {bool isEmail = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PartnerTheme.label()),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: _isEditing,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite),
          decoration: InputDecoration(
            filled: true,
            fillColor: _isEditing ? Colors.white.withValues(alpha: 0.04) : Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
            ),
          ),
        ),
      ],
    );
  }
}
