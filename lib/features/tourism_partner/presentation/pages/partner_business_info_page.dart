import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../partner_theme.dart';

class PartnerBusinessInfoPage extends ConsumerStatefulWidget {
  const PartnerBusinessInfoPage({super.key});

  @override
  ConsumerState<PartnerBusinessInfoPage> createState() => _PartnerBusinessInfoPageState();
}

class _PartnerBusinessInfoPageState extends ConsumerState<PartnerBusinessInfoPage> {
  bool _isEditing = false;
  bool _isSaving = false;

  final _businessNameCtrl = TextEditingController(text: 'Explorer Tourism Services');
  final _tradeNameCtrl = TextEditingController(text: 'Explorer Bohol Tours');
  final _typeCtrl = TextEditingController(text: 'Tourism Operator');
  final _tinCtrl = TextEditingController(text: '123-456-789-000');
  final _dtiCtrl = TextEditingController(text: 'DTI-07-2024-0012345');
  final _phoneCtrl = TextEditingController(text: '+63 32 422 1234');
  final _mobileCtrl = TextEditingController(text: '+63 917 123 4567');
  final _emailCtrl = TextEditingController(text: 'info@explorerboholtours.com');
  final _websiteCtrl = TextEditingController(text: 'www.explorerboholtours.com');
  final _addressCtrl = TextEditingController(text: '123 Tourism Road, Tubigon, Bohol 6329');
  final _descCtrl = TextEditingController(
    text: 'Explorer Tourism Services is a premier tourism operator based in Tubigon, Bohol, offering world-class island hopping, diving, and wildlife tours since 2020.',
  );
  final _operatingHoursCtrl = TextEditingController(text: '7:00 AM – 6:00 PM daily');

  final _bankNameCtrl = TextEditingController(text: 'BDO Unibank');
  final _accountNameCtrl = TextEditingController(text: 'Explorer Tourism Services');
  final _accountNumberCtrl = TextEditingController(text: '****-****-1234');

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _tradeNameCtrl.dispose();
    _typeCtrl.dispose();
    _tinCtrl.dispose();
    _dtiCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _operatingHoursCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    super.dispose();
  }

  void _saveBusinessInfo() {
    setState(() => _isSaving = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business information updated!'), backgroundColor: PartnerTheme.green),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Business Information', style: PartnerTheme.headingLarge()),
                        const SizedBox(width: 12),
                        const PartnerBadge(label: 'Verified Business', type: PartnerBadgeType.green),
                        const SizedBox(width: 6),
                        const PartnerBadge(label: 'Premium Partner', type: PartnerBadgeType.orange),
                      ],
                    ),
                    Text('Registered business accreditation, legal credentials, and payout account.', style: PartnerTheme.label()),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_isEditing) {
                            _saveBusinessInfo();
                          } else {
                            setState(() => _isEditing = true);
                          }
                        },
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded, size: 18),
                  label: Text(_isEditing ? 'Save Info' : 'Edit Business Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PartnerTheme.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 1: Business Details
            Container(
              padding: const EdgeInsets.all(28),
              decoration: PartnerTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Legal Business Credentials', style: PartnerTheme.headingMedium()),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _field('BUSINESS NAME', _businessNameCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _field('TRADE / OPERATING NAME', _tradeNameCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: _field('BUSINESS TYPE', _typeCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _field('TIN NUMBER', _tinCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _field('DTI REGISTRATION', _dtiCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: _field('TELEPHONE', _phoneCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _field('MOBILE', _mobileCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _field('EMAIL ADDRESS', _emailCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: _field('WEBSITE', _websiteCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _field('OPERATING HOURS', _operatingHoursCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _field('BUSINESS ADDRESS', _addressCtrl),
                  const SizedBox(height: 16),

                  _field('BUSINESS DESCRIPTION', _descCtrl, maxLines: 3),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Compliance Documents
            Container(
              padding: const EdgeInsets.all(28),
              decoration: PartnerTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accreditation & Permits', style: PartnerTheme.headingMedium()),
                  Text('Government compliance and municipal tourism verification.', style: PartnerTheme.label()),
                  const SizedBox(height: 16),

                  _docRow('DTI Business Registration', 'Jan 15, 2024', 'Jan 15, 2027', 'verified', '📄'),
                  const Divider(height: 1, color: Color(0x1AFFFFFF)),
                  _docRow('DOT Accreditation Certificate', 'Mar 5, 2024', 'Mar 5, 2026', 'verified', '🏛️'),
                  const Divider(height: 1, color: Color(0x1AFFFFFF)),
                  _docRow("Mayor's Permit 2026", 'Jan 2, 2026', 'Dec 31, 2026', 'verified', '📋'),
                  const Divider(height: 1, color: Color(0x1AFFFFFF)),
                  _docRow('BIR Form 2303 Certificate', 'Submitted Aug 1, 2026', '—', 'pending', '🔏'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Banking & Payout Info
            Container(
              padding: const EdgeInsets.all(28),
              decoration: PartnerTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payout & Bank Account', style: PartnerTheme.headingMedium()),
                  Text('Bank details used for automatic weekly payout disbursements.', style: PartnerTheme.label()),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _field('BANK NAME', _bankNameCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _field('ACCOUNT NAME', _accountNameCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _field('ACCOUNT NUMBER', _accountNumberCtrl)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docRow(String name, String date, String exp, String status, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: PartnerTheme.textWhite)),
                Text('Issued: $date • Expires: $exp', style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.textDisabled)),
              ],
            ),
          ),
          PartnerBadge(
            label: status,
            type: status == 'verified' ? PartnerBadgeType.green : PartnerBadgeType.orange,
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {int maxLines = 1}) {
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
