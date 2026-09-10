import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../emergency/models/emergency_contact.dart';
import '../../../emergency/repositories/emergency_repository.dart';
import '../../../map/providers/map_provider.dart';
import '../../providers/lgu_providers.dart';

class LguEmergencyContactsPage extends ConsumerStatefulWidget {
  const LguEmergencyContactsPage({super.key});

  @override
  ConsumerState<LguEmergencyContactsPage> createState() =>
      _LguEmergencyContactsPageState();
}

class _LguEmergencyContactsPageState
    extends ConsumerState<LguEmergencyContactsPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _orange = Color(0xFFF97316);

  List<EmergencyContact> _contacts = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _query = '';
  String _category = 'all';
  String _verification = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await ref.read(lguRepositoryProvider).getEmergencyContacts();
      if (!mounted) return;
      setState(() {
        _contacts = rows.map(EmergencyContact.fromJson).toList(growable: false);
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Emergency contacts could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm([EmergencyContact? contact]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ContactFormDialog(contact: contact),
    );
    if (data == null) return;
    await _runAction(
      contact == null
          ? () => ref.read(lguRepositoryProvider).createEmergencyContact(data)
          : () => ref
              .read(lguRepositoryProvider)
              .updateEmergencyContact(contact.uuid, data),
      contact == null ? 'Contact added.' : 'Contact updated.',
    );
  }

  Future<void> _runAction(
    Future<bool> Function() operation,
    String successMessage,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    var success = false;
    try {
      success = await operation();
      if (!mounted) return;
      if (success) {
        ref.invalidate(emergencyContactsListProvider);
        ref.invalidate(mapMarkersProvider);
        ref.invalidate(lguDashboardStatsProvider);
        ref.invalidate(lguActivityProvider);
      }
    } catch (_) {
      success = false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? successMessage
          : 'The change was not saved. Check the fields and try again.'),
      backgroundColor: success ? AppColors.success : AppColors.error,
    ));
    if (success) await _load();
  }

  Future<void> _archive(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive emergency contact?'),
        content: Text(
          '${contact.name} will be retained for audit history and removed from active directories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        () => ref
            .read(lguRepositoryProvider)
            .archiveEmergencyContact(contact.uuid),
        'Contact archived. No data was permanently deleted.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _contacts.map((item) => item.category).toSet().toList()
      ..sort();
    final filtered = _contacts.where((contact) {
      final matchesQuery =
          '${contact.name} ${contact.phone} ${contact.address} ${contact.category}'
              .toLowerCase()
              .contains(_query);
      final matchesCategory =
          _category == 'all' || contact.category == _category;
      final matchesVerification =
          _verification == 'all' || contact.verificationStatus == _verification;
      return matchesQuery && matchesCategory && matchesVerification;
    }).toList();
    return Scaffold(
      backgroundColor: _navyDark,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        onPressed: _saving ? null : () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Contact'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const Text(
              'Emergency Contacts Management',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'LGU-managed directory. Changes are published through Laravel/MySQL to the Tourist page.',
              style: TextStyle(color: AppColors.grey400),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(
                width: 290,
                child: TextField(
                  decoration: const InputDecoration(
                      labelText: 'Search agency, number, or address',
                      prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      categories.contains(_category) || _category == 'all'
                          ? _category
                          : 'all',
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['all', ...categories]
                      .map((value) => DropdownMenuItem(
                          value: value,
                          child:
                              Text(value == 'all' ? 'All categories' : value)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _verification,
                  decoration: const InputDecoration(labelText: 'Verification'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(
                        value: 'verified', child: Text('Verified')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                        value: 'needs_reverification',
                        child: Text('Needs reverification')),
                    DropdownMenuItem(
                        value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) =>
                      setState(() => _verification = value ?? 'all'),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (_saving) const LinearProgressIndicator(color: _orange),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(color: _orange)),
              )
            else if (_error != null)
              _StateCard(message: _error!, onRetry: _load)
            else if (filtered.isEmpty)
              _StateCard(
                message: _contacts.isEmpty
                    ? 'No emergency contacts have been added yet.'
                    : 'No emergency contacts match these filters.',
                onRetry: _load,
              )
            else
              ...filtered.map((contact) => _ContactCard(
                    contact: contact,
                    disabled: _saving,
                    onEdit: () => _openForm(contact),
                    onLocation: () => _openForm(contact),
                    onVerify: contact.isVerified
                        ? null
                        : () => _runAction(
                              () => ref
                                  .read(lguRepositoryProvider)
                                  .verifyEmergencyContact(contact.uuid),
                              'Contact verified.',
                            ),
                    onReverify: contact.verificationStatus == 'verified'
                        ? () => _runAction(
                              () => ref
                                  .read(lguRepositoryProvider)
                                  .setEmergencyContactVerification(
                                    contact.uuid,
                                    'needs_reverification',
                                  ),
                              'Contact marked for reverification and removed from the public directory.',
                            )
                        : null,
                    onStatus: () => _runAction(
                      () => ref
                          .read(lguRepositoryProvider)
                          .setEmergencyContactActive(
                            contact.uuid,
                            !contact.isActive,
                          ),
                      contact.isActive
                          ? 'Contact deactivated.'
                          : 'Contact activated.',
                    ),
                    onArchive: () => _archive(contact),
                  )),
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.disabled,
    required this.onEdit,
    required this.onLocation,
    required this.onVerify,
    required this.onReverify,
    required this.onStatus,
    required this.onArchive,
  });

  final EmergencyContact contact;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onLocation;
  final VoidCallback? onVerify;
  final VoidCallback? onReverify;
  final VoidCallback onStatus;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final updated = contact.updatedAt == null
        ? 'Not recorded'
        : DateFormat.yMMMd().add_jm().format(contact.updatedAt!.toLocal());
    final verified = contact.lastVerifiedAt == null
        ? 'Not verified'
        : DateFormat.yMMMd().format(contact.lastVerifiedAt!.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: contact.isActive
              ? const Color(0xFFF97316).withValues(alpha: .35)
              : Colors.redAccent.withValues(alpha: .35),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(
            backgroundColor: Color(0x332563EB),
            child: Icon(Icons.emergency_rounded, color: Color(0xFFF97316)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                Text('${contact.category} • ${contact.phone}',
                    style: const TextStyle(color: AppColors.grey400)),
              ],
            ),
          ),
          _Badge(
            label: contact.isActive ? 'Active' : 'Inactive',
            color: contact.isActive ? AppColors.success : AppColors.error,
          ),
        ]),
        if (contact.alternativePhone?.isNotEmpty == true)
          Text('Alternative: ${contact.alternativePhone}',
              style: const TextStyle(color: AppColors.grey300)),
        if (contact.address?.isNotEmpty == true)
          Text(contact.address!,
              style: const TextStyle(color: AppColors.grey400)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Badge(
            label: contact.verificationStatus.replaceAll('_', ' '),
            color: contact.verificationStatus == 'verified'
                ? AppColors.success
                : AppColors.warning,
          ),
          _Badge(
            label: contact.isPublic ? 'Public' : 'Private',
            color: contact.isPublic ? AppColors.success : AppColors.grey400,
          ),
          _Badge(
            label: contact.classification == 'emergency'
                ? 'Emergency'
                : 'Non-emergency',
            color: const Color(0xFFF97316),
          ),
        ]),
        const SizedBox(height: 10),
        Text('Last Updated: $updated',
            style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
        Text('Updated By: ${contact.updatedByName ?? 'System'}',
            style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
        Text('Last Verified: $verified',
            style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
        Text('Verified By: ${contact.verifiedByName ?? 'Not verified'}',
            style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
        if (contact.sourceName?.isNotEmpty == true)
          Text('Source: ${contact.sourceName}',
              style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _ActionButton(
              icon: Icons.edit_rounded,
              label: 'Edit',
              onPressed: disabled ? null : onEdit),
          _ActionButton(
              icon: Icons.location_on_rounded,
              label: 'Update Location',
              onPressed: disabled ? null : onLocation),
          if (!contact.isVerified)
            _ActionButton(
                icon: Icons.verified_rounded,
                label: 'Verify',
                onPressed: disabled ? null : onVerify),
          if (onReverify != null)
            _ActionButton(
                icon: Icons.fact_check_outlined,
                label: 'Require Reverification',
                onPressed: disabled ? null : onReverify),
          _ActionButton(
            icon: contact.isActive
                ? Icons.block_rounded
                : Icons.check_circle_rounded,
            label: contact.isActive ? 'Deactivate' : 'Activate',
            onPressed: disabled ? null : onStatus,
          ),
          _ActionButton(
              icon: Icons.archive_rounded,
              label: 'Archive',
              onPressed: disabled ? null : onArchive),
        ]),
      ]),
    );
  }
}

class _ContactFormDialog extends StatefulWidget {
  const _ContactFormDialog({this.contact});
  final EmergencyContact? contact;

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late String _classification;
  late bool _isActive;
  late bool _isPublic;
  late String _category;

  static const _categories = <String>[
    'Police',
    'Fire',
    'Medical',
    'Disaster Risk',
    'Coast Guard',
    'Government',
    'Red Cross',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _fields = {
      'name': TextEditingController(text: c?.name),
      'phone': TextEditingController(text: c?.phone),
      'alternative_phone': TextEditingController(text: c?.alternativePhone),
      'address': TextEditingController(text: c?.address),
      'barangay': TextEditingController(text: c?.barangay),
      'description': TextEditingController(text: c?.description),
      'operating_hours': TextEditingController(text: c?.operatingHours),
      'availability_notes': TextEditingController(text: c?.availabilityNotes),
      'emergency_instructions':
          TextEditingController(text: c?.emergencyInstructions),
      'latitude': TextEditingController(text: c?.latitude?.toString()),
      'longitude': TextEditingController(text: c?.longitude?.toString()),
      'source': TextEditingController(text: c?.source),
      'source_name': TextEditingController(text: c?.sourceName),
      'source_url': TextEditingController(text: c?.sourceUrl),
    };
    _classification = c?.classification ?? 'emergency';
    _isActive = c?.isActive ?? true;
    _isPublic = c?.isPublic ?? true;
    _category = _categories.contains(c?.category) ? c!.category : 'Government';
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    String? optional(String key) {
      final value = _fields[key]!.text.trim();
      return value.isEmpty ? null : value;
    }

    Navigator.pop(context, <String, dynamic>{
      'name': _fields['name']!.text.trim(),
      'category': _category,
      'phone': _fields['phone']!.text.trim(),
      'alternative_phone': optional('alternative_phone'),
      'address': optional('address'),
      'barangay': optional('barangay'),
      'description': optional('description'),
      'operating_hours': optional('operating_hours'),
      'availability_notes': optional('availability_notes'),
      'emergency_instructions': optional('emergency_instructions'),
      'classification': _classification,
      'is_active': _isActive,
      'is_public': _isPublic,
      'latitude': double.tryParse(_fields['latitude']!.text.trim()),
      'longitude': double.tryParse(_fields['longitude']!.text.trim()),
      'source': optional('source'),
      'source_name': optional('source_name'),
      'source_url': optional('source_url'),
    });
  }

  Future<void> _pickLocation() async {
    final latitude =
        double.tryParse(_fields['latitude']!.text.trim()) ?? 9.9515;
    final longitude =
        double.tryParse(_fields['longitude']!.text.trim()) ?? 123.9618;
    final result = await context.push<Map<String, dynamic>>(
      '/map/pick?mode=place&lat=$latitude&lng=$longitude',
    );
    if (!mounted || result == null) return;
    setState(() {
      _fields['latitude']!.text = result['latitude']?.toString() ?? '';
      _fields['longitude']!.text = result['longitude']?.toString() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: Text(widget.contact == null ? 'Add Contact' : 'Edit Contact',
            style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 560,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(children: [
                _field('name', 'Contact / agency name', required: true),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: const Color(0xFF1C2541),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'Government'),
                ),
                const SizedBox(height: 10),
                _field('phone', 'Primary phone', required: true),
                _field('alternative_phone', 'Alternative phone'),
                _field('address', 'Address', lines: 2),
                _field('barangay', 'Barangay'),
                _field('description', 'Description / instructions', lines: 3),
                _field('operating_hours', 'Operating hours'),
                _field('availability_notes', 'Availability notes', lines: 2),
                _field('emergency_instructions', 'Emergency instructions',
                    lines: 3),
                Row(children: [
                  Expanded(
                    child: _field('latitude', 'Latitude', numeric: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field('longitude', 'Longitude', numeric: true),
                  ),
                ]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Choose on Map'),
                  ),
                ),
                const SizedBox(height: 10),
                _field('source', 'Verification source'),
                _field('source_name', 'Exact source / office name'),
                _field('source_url', 'Source URL'),
                DropdownButtonFormField<String>(
                  initialValue: _classification,
                  dropdownColor: const Color(0xFF1C2541),
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Classification'),
                  items: const [
                    DropdownMenuItem(
                        value: 'emergency', child: Text('Emergency')),
                    DropdownMenuItem(
                        value: 'non_emergency', child: Text('Non-emergency')),
                  ],
                  onChanged: (value) =>
                      setState(() => _classification = value ?? 'emergency'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Only active contacts appear to tourists.',
                      style: TextStyle(color: AppColors.grey400)),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public directory',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Publication still requires active and verified status.',
                      style: TextStyle(color: AppColors.grey400)),
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(onPressed: _submit, child: const Text('Save Changes')),
        ],
      );

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool numeric = false,
    int lines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: _fields[key],
          validator: required ? _required : null,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          maxLines: lines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2541),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          const Icon(Icons.emergency_rounded,
              color: Color(0xFFF97316), size: 44),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey300)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}
