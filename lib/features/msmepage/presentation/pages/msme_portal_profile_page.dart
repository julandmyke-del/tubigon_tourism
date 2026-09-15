import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../map/providers/map_provider.dart';
import '../../providers/msme_portal_providers.dart';
import '../../repositories/msme_repository.dart';
import '../msme_theme.dart';
import '../widgets/msme_portal_states.dart';

class MsmePortalProfilePage extends ConsumerStatefulWidget {
  const MsmePortalProfilePage({super.key});

  @override
  ConsumerState<MsmePortalProfilePage> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<MsmePortalProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  String? _categoryId;
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
  bool _uploading = false;
  bool _bookingEnabled = false;
  String _operationalStatus = 'open';
  String? _businessId;
  final List<String> _images = [];
  final Map<String, bool> _closed = {
    for (final day in const [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ])
      day: false,
  };

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
          message: friendlyMsmeError(
              error, 'We couldn’t load your business profile.'),
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
                              : () {
                                  final hasLocation =
                                      data['latitude'] != null &&
                                          data['longitude'] != null;
                                  if (hasLocation) {
                                    context
                                        .push('/map?marker=msme:$_businessId');
                                  } else if (data['integer_id'] != null) {
                                    context.push(
                                        '/explore/msme/${data['integer_id']}');
                                  }
                                },
                          icon: const Icon(Icons.visibility_rounded),
                          label: Text(data['latitude'] != null &&
                                  data['longitude'] != null
                              ? (status == 'verified'
                                  ? 'Preview on Map'
                                  : 'Private Map Preview')
                              : 'Preview Directory Details'),
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
                              _categoryField(),
                              _field('Phone / contact', _phone),
                              _field('Tagline', _tagline),
                            ]),
                            const SizedBox(height: 12),
                            _field('Address', _address),
                            const SizedBox(height: 12),
                            _field('Description', _description, lines: 4),
                            const SizedBox(height: 20),
                            Text('Media', style: MsmeTheme.headingSmall()),
                            const SizedBox(height: 4),
                            Text(
                                'Upload a cover or gallery image (JPEG/PNG/WebP, maximum 5 MB).',
                                style: TextStyle(color: MsmeTheme.textMuted)),
                            const SizedBox(height: 10),
                            if (_images.isNotEmpty)
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _images
                                    .asMap()
                                    .entries
                                    .map((entry) => Stack(children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.network(entry.value,
                                                width: 150,
                                                height: 95,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      width: 150,
                                                      height: 95,
                                                      color:
                                                          MsmeTheme.surfaceDark,
                                                      child: const Icon(Icons
                                                          .broken_image_rounded),
                                                    )),
                                          ),
                                          Positioned(
                                            right: 4,
                                            top: 4,
                                            child: IconButton.filled(
                                              tooltip:
                                                  'Remove image from profile',
                                              onPressed: _saving
                                                  ? null
                                                  : () => setState(() => _images
                                                      .removeAt(entry.key)),
                                              icon: const Icon(Icons.close,
                                                  size: 16),
                                            ),
                                          ),
                                        ]))
                                    .toList(),
                              ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _uploading || _images.length >= 10
                                  ? null
                                  : _pickImage,
                              icon: _uploading
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(
                                      Icons.add_photo_alternate_rounded),
                              label:
                                  Text(_uploading ? 'Uploading…' : 'Add image'),
                            ),
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
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _bookingEnabled,
                              title: const Text('Accept customer reservations'),
                              subtitle: const Text(
                                  'Enable only if this business supports advance booking.'),
                              onChanged: (value) =>
                                  setState(() => _bookingEnabled = value),
                            ),
                            const SizedBox(height: 16),
                            Text('Map location',
                                style: MsmeTheme.headingSmall()),
                            const SizedBox(height: 8),
                            _responsiveFields([
                              _field('Latitude', _latitude, numeric: true),
                              _field('Longitude', _longitude, numeric: true),
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
                            Text(
                                'Use 24-hour HH:mm-HH:mm, or leave blank for Closed.',
                                style: TextStyle(color: MsmeTheme.textMuted)),
                            const SizedBox(height: 10),
                            ..._hours.entries.map(_scheduleRow),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _copyMondaySchedule,
                                icon: const Icon(Icons.copy_all_rounded),
                                label: const Text('Copy Monday to all days'),
                              ),
                            ),
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
                            ? 'Save Business Draft'
                            : 'Save Profile'),
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
    _categoryId = data['category_id']?.toString() ??
        (data['category_record'] is Map
            ? (data['category_record'] as Map)['id']?.toString()
            : null);
    _tagline.text = data['tagline']?.toString() ?? '';
    _phone.text = data['phone']?.toString() ?? '';
    _address.text = data['address']?.toString() ?? '';
    _description.text = data['description']?.toString() ?? '';
    _latitude.text = data['latitude']?.toString() ?? '';
    _longitude.text = data['longitude']?.toString() ?? '';
    _operationalStatus = data['operational_status']?.toString() ?? 'open';
    _bookingEnabled =
        data['booking_enabled'] == true || data['booking_enabled'] == 1;
    _images
      ..clear()
      ..addAll(
          (data['images'] as List? ?? const []).map((item) => item.toString()));
    final opening = data['opening_hours'];
    if (opening is Map) {
      for (final entry in _hours.entries) {
        final value = opening[entry.key];
        if (value is Map) {
          _closed[entry.key] = value['closed'] == true;
          if (value['closed'] != true) {
            entry.value.text = '${value['open'] ?? ''}-${value['close'] ?? ''}';
          }
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
        if (_categoryId?.startsWith('legacy:') == true)
          'category': _category.text.trim()
        else
          'category_id': _categoryId,
        'tagline': _tagline.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'description': _description.text.trim(),
        'latitude': double.tryParse(_latitude.text.trim()),
        'longitude': double.tryParse(_longitude.text.trim()),
        'operational_status': _operationalStatus,
        'booking_enabled': _bookingEnabled,
        'images': _images,
        'opening_hours': {
          for (final entry in _hours.entries)
            entry.key: (_closed[entry.key] ?? false)
                ? {'closed': true}
                : _hoursValue(entry.value.text),
        },
      };
      final repo = ref.read(msmePortalRepositoryProvider);
      if (_businessId == null) {
        await repo.createListing(payload, saveAsDraft: true);
      } else {
        await repo.updateProfile(payload);
      }
      if (!mounted) return;
      _refresh();
      if (mounted) {
        _message(_businessId == null
            ? 'Business draft saved. Review it, then submit for LGU verification.'
            : 'Business profile saved.');
      }
    } catch (error) {
      if (mounted) {
        _message(
            friendlyMsmeError(error, 'We couldn’t save your business profile.'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(msmePortalRepositoryProvider).submitProfile();
      if (!mounted) return;
      _refresh();
      if (mounted) _message('Business submitted for review.');
    } catch (error) {
      if (mounted) {
        _message(
            friendlyMsmeError(
                error, 'We couldn’t submit your business profile.'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _refresh() {
    _initialized = false;
    ref.invalidate(currentMsmeProvider);
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

  Widget _categoryField() {
    return ref.watch(msmeCategoriesProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => OutlinedButton.icon(
            onPressed: () => ref.invalidate(msmeCategoriesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry loading categories'),
          ),
          data: (categories) {
            final legacyValue = _category.text.trim().isEmpty
                ? null
                : 'legacy:${_category.text.trim()}';
            final knownSelection =
                categories.any((item) => item.id == _categoryId);
            final selected = knownSelection ? _categoryId : legacyValue;
            return DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Category / type *'),
              items: [
                ...categories.map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    )),
                if (legacyValue != null && !knownSelection)
                  DropdownMenuItem(
                    value: legacyValue,
                    child: Text('${_category.text.trim()} (legacy)'),
                  ),
              ],
              onChanged: (value) {
                _categoryId = value;
                if (value == null) {
                  _category.clear();
                } else if (!value.startsWith('legacy:')) {
                  _category.text =
                      categories.firstWhere((item) => item.id == value).name;
                }
              },
              validator: (value) => value == null || value.isEmpty
                  ? 'Category / type is required.'
                  : null,
            );
          },
        );
  }

  Widget _scheduleRow(MapEntry<String, TextEditingController> entry) {
    final hoursField = TextFormField(
      controller: entry.value,
      enabled: !(_closed[entry.key] ?? false),
      decoration: const InputDecoration(
        labelText: 'Opening - closing',
        hintText: '08:00-18:00',
      ),
      validator: (value) {
        if (_closed[entry.key] ?? false) return null;
        final parts = (value ?? '').split('-');
        if (parts.length != 2 ||
            parts.any(
              (part) => !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(part),
            )) {
          return 'Use HH:mm-HH:mm.';
        }
        return parts[1].compareTo(parts[0]) <= 0
            ? 'Closing must be after opening.'
            : null;
      },
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayToggle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 105,
                child: Text(
                  _title(entry.key),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Switch.adaptive(
                value: !(_closed[entry.key] ?? false),
                onChanged: (open) => setState(() => _closed[entry.key] = !open),
              ),
            ],
          );

          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [dayToggle, hoursField],
            );
          }

          return Row(
            children: [dayToggle, Expanded(child: hoursField)],
          );
        },
      ),
    );
  }

  void _copyMondaySchedule() {
    final value = _hours['monday']!.text;
    final closed = _closed['monday'] ?? false;
    setState(() {
      for (final entry in _hours.entries) {
        entry.value.text = value;
        _closed[entry.key] = closed;
      }
    });
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2200,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('The selected image exceeds the 5 MB limit.');
      }
      final url = await ref
          .read(msmePortalRepositoryProvider)
          .uploadImage(file.name, bytes);
      if (!mounted) return;
      setState(() => _images.add(url));
    } catch (error) {
      if (mounted) {
        _message(friendlyMsmeError(error, 'The image could not be uploaded.'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
      style: TextStyle(color: MsmeTheme.textWhite),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (isRequired && text.isEmpty) return '$label is required.';
        if (numeric && text.isNotEmpty) {
          final parsed = double.tryParse(text);
          if (parsed == null) return 'Enter a valid number.';
          if (label == 'Latitude' && (parsed < -90 || parsed > 90)) {
            return 'Latitude must be between -90 and 90.';
          }
          if (label == 'Longitude' && (parsed < -180 || parsed > 180)) {
            return 'Longitude must be between -180 and 180.';
          }
        }
        return null;
      },
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
