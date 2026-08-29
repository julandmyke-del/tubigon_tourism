import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../map/providers/map_provider.dart';
import '../../providers/msme_portal_providers.dart';
import '../../repositories/msme_repository.dart';
import '../msme_theme.dart';

class MsmePortalProfilePage extends ConsumerStatefulWidget {
  const MsmePortalProfilePage({super.key});

  @override
  ConsumerState<MsmePortalProfilePage> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<MsmePortalProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _tagline = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _hours = <String, TextEditingController>{
    for (final day in const [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ])
      day: TextEditingController(),
  };
  bool _initialized = false;
  bool _saving = false;
  String _operationalStatus = 'open';
  String? _businessId;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _category,
      _tagline,
      _phone,
      _address,
      _description,
      _latitude,
      _longitude,
      ..._hours.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(msmePortalProfileProvider);
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          retry: () => ref.invalidate(msmePortalProfileProvider),
        ),
        data: (data) {
          _initialize(data);
          final status =
              data['verification_status']?.toString() ?? 'not_submitted';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                            _businessId == null
                                ? 'Business Setup'
                                : 'Business Profile',
                            style: MsmeTheme.headingLarge()),
                        _StatusChip(status: status),
                        OutlinedButton.icon(
                          onPressed: _businessId == null
                              ? null
                              : () =>
                                  context.push('/map?marker=msme:$_businessId'),
                          icon: const Icon(Icons.visibility_rounded),
                          label: Text(status == 'verified'
                              ? 'Preview as Tourist'
                              : 'Private Preview'),
                        ),
                      ],
                    ),
                    if ((data['verification_notes']?.toString() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Notice(text: data['verification_notes'].toString()),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: MsmeTheme.cardDecoration(),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Business information',
                                style: MsmeTheme.headingSmall()),
                            const SizedBox(height: 16),
                            _responsiveFields([
                              _field('Business name', _name, isRequired: true),
                              _field('Category / type', _category,
                                  isRequired: true),
                              _field('Phone / contact', _phone,
                                  isRequired: true),
                              _field('Tagline', _tagline),
                            ]),
                            const SizedBox(height: 12),
                            _field('Address', _address, isRequired: true),
                            const SizedBox(height: 12),
                            _field('Description', _description, lines: 4),
                            const SizedBox(height: 16),
                            Text('Operational availability',
                                style: MsmeTheme.headingSmall()),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _operationalStatus,
                              dropdownColor: MsmeTheme.cardDark,
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(
                                    value: 'open', child: Text('Open')),
                                DropdownMenuItem(
                                    value: 'temporarily_closed',
                                    child: Text('Temporarily closed')),
                                DropdownMenuItem(
                                    value: 'fully_booked',
                                    child: Text('Fully booked')),
                              ],
                              onChanged: (value) => setState(
                                  () => _operationalStatus = value ?? 'open'),
                            ),
                            const SizedBox(height: 16),
                            Text('Map location',
                                style: MsmeTheme.headingSmall()),
                            const SizedBox(height: 8),
                            _responsiveFields([
                              _field('Latitude', _latitude,
                                  isRequired: true, numeric: true),
                              _field('Longitude', _longitude,
                                  isRequired: true, numeric: true),
                            ]),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _pickLocation,
                              icon: const Icon(Icons.map_rounded),
                              label: const Text('Set location on Smart Map'),
                            ),
                            const SizedBox(height: 20),
                            Text('Opening hours',
                                style: MsmeTheme.headingSmall()),
                            const SizedBox(height: 4),
                            const Text(
                                'Use 24-hour HH:mm-HH:mm, or leave blank for Closed.',
                                style: TextStyle(color: MsmeTheme.textMuted)),
                            const SizedBox(height: 10),
                            _responsiveFields(_hours.entries
                                .map((entry) => _field(
                                    _title(entry.key), entry.value,
                                    hint: '08:00-18:00'))
                                .toList()),
                          ]),
                    ),
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: Text(_businessId == null
                            ? 'Create and submit'
                            : 'Save profile'),
                      ),
                      if (_businessId != null &&
                          status != 'verified' &&
                          status != 'pending')
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Submit for review'),
                        ),
                    ]),
                  ]),
            ),
          );
        },
      ),
    );
  }

  void _initialize(Map<String, dynamic> data) {
    if (_initialized) return;
    _businessId = data['id']?.toString();
    _name.text = data['name']?.toString() ?? '';
    _category.text = data['category']?.toString() ?? '';
    _tagline.text = data['tagline']?.toString() ?? '';
    _phone.text = data['phone']?.toString() ?? '';
    _address.text = data['address']?.toString() ?? '';
    _description.text = data['description']?.toString() ?? '';
    _latitude.text = data['latitude']?.toString() ?? '';
    _longitude.text = data['longitude']?.toString() ?? '';
    _operationalStatus = data['operational_status']?.toString() ?? 'open';
    final opening = data['opening_hours'];
    if (opening is Map) {
      for (final entry in _hours.entries) {
        final value = opening[entry.key];
        if (value is Map && value['closed'] != true) {
          entry.value.text = '${value['open'] ?? ''}-${value['close'] ?? ''}';
        }
      }
    }
    _initialized = true;
  }

  Future<void> _pickLocation() async {
    final lat = double.tryParse(_latitude.text) ?? 9.9515;
    final lng = double.tryParse(_longitude.text) ?? 123.9618;
    final result = await context
        .push<Map<String, dynamic>>('/map/pick?mode=place&lat=$lat&lng=$lng');
    if (result == null || !mounted) return;
    setState(() {
      _latitude.text = result['latitude']?.toString() ?? '';
      _longitude.text = result['longitude']?.toString() ?? '';
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'category': _category.text.trim(),
        'tagline': _tagline.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'description': _description.text.trim(),
        'latitude': double.parse(_latitude.text),
        'longitude': double.parse(_longitude.text),
        'operational_status': _operationalStatus,
        'opening_hours': {
          for (final entry in _hours.entries)
            entry.key: _hoursValue(entry.value.text),
        },
      };
      final repo = ref.read(msmePortalRepositoryProvider);
      if (_businessId == null) {
        await repo.createListing(payload);
      } else {
        await repo.updateProfile(payload);
      }
      _refresh();
      if (mounted) {
        _message(_businessId == null
            ? 'Business submitted for review.'
            : 'Business profile saved.');
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(msmePortalRepositoryProvider).submitProfile();
      _refresh();
      if (mounted) _message('Business submitted for review.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _refresh() {
    _initialized = false;
    ref.invalidate(msmePortalProfileProvider);
    ref.invalidate(msmePortalDashboardStatsProvider);
    ref.invalidate(msmePortalListingsProvider);
    ref.invalidate(msmeListProvider);
    ref.invalidate(mapMarkersProvider);
  }

  Map<String, dynamic> _hoursValue(String raw) {
    final parts = raw.trim().split('-');
    if (parts.length != 2 ||
        parts.any((value) => !RegExp(r'^\d{2}:\d{2}$').hasMatch(value))) {
      return {'closed': true};
    }
    return {'closed': false, 'open': parts[0], 'close': parts[1]};
  }

  Widget _responsiveFields(List<Widget> fields) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 720
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: fields
                .map((field) => SizedBox(width: width, child: field))
                .toList());
      });

  Widget _field(String label, TextEditingController controller,
      {bool isRequired = false,
      bool numeric = false,
      int lines = 1,
      String? hint}) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType:
          numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
      style: const TextStyle(color: MsmeTheme.textWhite),
      validator: isRequired
          ? (value) => (value == null || value.trim().isEmpty)
              ? '$label is required.'
              : null
          : null,
      decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: MsmeTheme.surfaceDark),
    );
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: error ? MsmeTheme.red : MsmeTheme.green,
            content: Text(text)),
      );

  String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(status.replaceAll('_', ' ').toUpperCase()));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: MsmeTheme.amber.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: MsmeTheme.amber)),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, style: const TextStyle(color: MsmeTheme.red)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: retry, child: const Text('Retry')),
      ]));
}
