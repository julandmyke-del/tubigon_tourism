import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerCreateListingPage extends ConsumerStatefulWidget {
  const PartnerCreateListingPage({super.key, this.listingId});

  final String? listingId;

  @override
  ConsumerState<PartnerCreateListingPage> createState() => _PartnerCreateListingPageState();
}

class _PartnerCreateListingPageState extends ConsumerState<PartnerCreateListingPage> {
  int _currentStep = 1;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _maxGuestsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _highlightsCtrl = TextEditingController();
  final _inclusionsCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();

  String _category = 'Island Tour';
  String _status = 'active';

  static const _categories = [
    'Island Tour',
    'Diving',
    'Snorkeling',
    'Wildlife',
    'Adventure',
    'Dining',
    'Cruising',
    'Land Tour',
    'Cultural',
    'Water Sports'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.listingId != null) {
      _loadExistingListing();
    }
  }

  void _loadExistingListing() {
    _nameCtrl.text = 'Island Hopping Adventure';
    _locationCtrl.text = 'Tubigon Pier';
    _priceCtrl.text = '1800';
    _durationCtrl.text = '8';
    _maxGuestsCtrl.text = '15';
    _descCtrl.text = "Experience the stunning beauty of Bohol's surrounding islands on this full-day hopping adventure.";
    _highlightsCtrl.text = "Snorkeling at Pandanon Island\nFresh seafood lunch\nBeach volleyball";
    _inclusionsCtrl.text = "Round-trip boat transfer\nSnorkeling equipment\nLunch";
    _requirementsCtrl.text = "Must know how to swim\nBring sunscreen";
    _category = 'Island Tour';
    _status = 'active';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _maxGuestsCtrl.dispose();
    _descCtrl.dispose();
    _highlightsCtrl.dispose();
    _inclusionsCtrl.dispose();
    _requirementsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(tourismPartnerRepositoryProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'location': _locationCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'duration_hours': int.tryParse(_durationCtrl.text) ?? 0,
        'max_guests': int.tryParse(_maxGuestsCtrl.text) ?? 0,
        'description': _descCtrl.text.trim(),
        'highlights': _highlightsCtrl.text.trim(),
        'inclusions': _inclusionsCtrl.text.trim(),
        'requirements': _requirementsCtrl.text.trim(),
        'status': _status,
      };

      if (widget.listingId != null) {
        await repo.updateListing(widget.listingId!, data);
      } else {
        await repo.createListing(data);
      }

      ref.invalidate(partnerListingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.listingId != null ? 'Listing updated successfully!' : 'Listing created successfully!'),
            backgroundColor: PartnerTheme.green,
          ),
        );
        context.go('/tourism-partner/listings');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save listing: $e'),
            backgroundColor: PartnerTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.listingId != null;

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Listing' : 'Create New Listing',
                        style: PartnerTheme.headingLarge(),
                      ),
                      Text(
                        isEdit ? 'Update details of your offering' : 'Add a new tourist attraction, tour, or service',
                        style: PartnerTheme.label(),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/tourism-partner/listings'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PartnerTheme.textMuted,
                      side: const BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Step Wizard Header
              _buildStepIndicator(),
              const SizedBox(height: 28),

              // Step Content Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: PartnerTheme.cardDecoration(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildCurrentStepView(),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons (Back / Next / Submit)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 1)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep--),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PartnerTheme.textWhite,
                        side: const BorderSide(color: Color(0x1AFFFFFF)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    )
                  else
                    const SizedBox(),
                  ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () {
                            if (_currentStep < 3) {
                              setState(() => _currentStep++);
                            } else {
                              _submitForm();
                            }
                          },
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_currentStep == 3 ? Icons.check_circle_rounded : Icons.chevron_right_rounded),
                    label: Text(_currentStep == 3 ? (isEdit ? 'Save Changes' : 'Publish Listing') : 'Next Step'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PartnerTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      {'num': 1, 'label': 'Basic Info'},
      {'num': 2, 'label': 'Details'},
      {'num': 3, 'label': 'Review'},
    ];

    return Row(
      children: List.generate(steps.length, (idx) {
        final step = steps[idx];
        final num = step['num'] as int;
        final label = step['label'] as String;
        final isActive = _currentStep >= num;

        return Expanded(
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() => _currentStep = num),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: isActive ? PartnerTheme.orangeGradient : null,
                        color: isActive ? null : Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? PartnerTheme.primaryOrange : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$num',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : PartnerTheme.textDisabled,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? PartnerTheme.textWhite : PartnerTheme.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: _currentStep > num ? PartnerTheme.primaryOrange : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1BasicInfo();
      case 2:
        return _buildStep2Details();
      case 3:
      default:
        return _buildStep3Review();
    }
  }

  Widget _buildStep1BasicInfo() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 1: Basic Information', style: PartnerTheme.headingMedium()),
        Text('Enter the main details for your tour or attraction.', style: PartnerTheme.label()),
        const SizedBox(height: 20),

        _buildTextField('LISTING NAME', _nameCtrl, 'e.g. Island Hopping Adventure'),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CATEGORY', style: PartnerTheme.label()),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: PartnerTheme.cardDark,
                    style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite),
                    decoration: _inputDecoration(),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField('LOCATION', _locationCtrl, 'e.g. Tubigon Pier'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildTextField('PRICE (PHP)', _priceCtrl, 'e.g. 1800', isNumber: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField('DURATION (HOURS)', _durationCtrl, 'e.g. 8', isNumber: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField('MAX GUESTS', _maxGuestsCtrl, 'e.g. 15', isNumber: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2Details() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 2: Additional Details', style: PartnerTheme.headingMedium()),
        Text('Describe your listing and list what guests should expect.', style: PartnerTheme.label()),
        const SizedBox(height: 20),

        _buildTextField('DESCRIPTION', _descCtrl, 'Describe the experience…', maxLines: 3),
        const SizedBox(height: 16),

        _buildTextField('HIGHLIGHTS (1 PER LINE)', _highlightsCtrl, 'e.g. Snorkeling at Pandanon\nFresh Seafood', maxLines: 3),
        const SizedBox(height: 16),

        _buildTextField('INCLUSIONS (1 PER LINE)', _inclusionsCtrl, 'e.g. Lunch\nEquipment', maxLines: 3),
        const SizedBox(height: 16),

        _buildTextField('REQUIREMENTS / REMARKS', _requirementsCtrl, 'e.g. Must know how to swim', maxLines: 2),
      ],
    );
  }

  Widget _buildStep3Review() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 3: Review & Publish', style: PartnerTheme.headingMedium()),
        Text('Verify your listing details before saving.', style: PartnerTheme.label()),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              _reviewRow('Name', _nameCtrl.text),
              _reviewRow('Category', _category),
              _reviewRow('Location', _locationCtrl.text),
              _reviewRow('Price', '₱${_priceCtrl.text}'),
              _reviewRow('Duration', '${_durationCtrl.text} hours'),
              _reviewRow('Max Guests', _maxGuestsCtrl.text),
              _reviewRow('Description', _descCtrl.text),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: PartnerTheme.textMuted)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value, style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String placeholder, {int maxLines = 1, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PartnerTheme.label()),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite),
          decoration: _inputDecoration(placeholder: placeholder),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? placeholder}) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textDisabled),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PartnerTheme.primaryOrange),
      ),
    );
  }
}
