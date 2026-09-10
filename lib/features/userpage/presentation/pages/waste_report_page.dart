import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/utils/auth_action_guard.dart';
import '../../../map/providers/map_provider.dart';
import '../../../settings/repositories/settings_repository.dart';
import '../../../waste_reporting/repositories/waste_report_repository.dart';

class WasteReportPage extends ConsumerStatefulWidget {
  const WasteReportPage({super.key});

  @override
  ConsumerState<WasteReportPage> createState() => _WasteReportPageState();
}

class _WasteReportPageState extends ConsumerState<WasteReportPage> {
  final _locationCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  String? _categoryId;
  String? _categorySlug;
  String _severity = 'moderate';
  bool _isSubmitting = false;
  bool _isResolvingAddress = false;
  double? _latitude;
  double? _longitude;
  String? _resolvedAddress;
  String? _geocodingSource;
  final List<XFile> _photos = [];
  XFile? _video;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _barangayCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!await requireSignedIn(context, ref, returnTo: '/waste-report') ||
        !mounted) {
      return;
    }
    final desc = _descCtrl.text.trim();
    if (_categoryId == null || _categorySlug == null) {
      _message('Choose a waste category.');
      return;
    }
    if (desc.length < 10 || desc.length > 2000) {
      _message('Description must be between 10 and 2,000 characters.');
      return;
    }
    if (_latitude == null || _longitude == null) {
      _message('Use Current Location or confirm a pin on the map.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final synced = await ref.read(wasteReportRepositoryProvider).submitReport(
            categoryId: _categoryId!,
            categorySlug: _categorySlug!,
            severity: _severity,
            description: desc,
            latitude: _latitude,
            longitude: _longitude,
            locationText: _locationCtrl.text.trim().isEmpty
                ? 'Pinned map location'
                : _locationCtrl.text.trim(),
            barangay: _barangayCtrl.text.trim().isEmpty
                ? null
                : _barangayCtrl.text.trim(),
            resolvedAddress: _resolvedAddress,
            geocodingSource: _geocodingSource,
            photos: List.unmodifiable(_photos),
            video: _video,
          );
      ref.invalidate(myWasteReportsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor:
            synced ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        content: Text(synced
            ? 'Waste report submitted. You can follow its status in My Waste Reports.'
            : 'Offline copy saved. It will be submitted once this account is revalidated online.'),
      ));
      context.canPop() ? context.pop() : context.goNamed(RouteNames.home);
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportingEnabled = ref
            .watch(systemSettingsProvider)
            .valueOrNull?['waste_reporting_enabled'] !=
        false;
    final categories = ref.watch(wasteCategoriesProvider);
    final categoryItems =
        categories.valueOrNull ?? const <WasteCategoryOption>[];
    if (_categoryId == null && categoryItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _categoryId != null) return;
        setState(() {
          _categoryId = categoryItems.first.id;
          _categorySlug = categoryItems.first.slug;
        });
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(context.tr('report_issue')),
        actions: [
          IconButton(
            tooltip: 'My Waste Reports',
            onPressed: () => context.push('/waste-reports'),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _intro(),
          const SizedBox(height: 16),
          _section(
            title: '1. Issue details',
            icon: Icons.category_rounded,
            children: [
              categories.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Row(children: [
                  const Expanded(
                      child: Text(
                          'Waste categories are unavailable. Connect and retry before submitting.',
                          style: TextStyle(color: Color(0xFFFCA5A5)))),
                  IconButton(
                      onPressed: () => ref.invalidate(wasteCategoriesProvider),
                      icon: const Icon(Icons.refresh_rounded)),
                ]),
                data: (items) => DropdownButtonFormField<String>(
                  initialValue: items.any((item) => item.id == _categoryId)
                      ? _categoryId
                      : null,
                  decoration:
                      const InputDecoration(labelText: 'Waste category *'),
                  items: items
                      .map((item) => DropdownMenuItem(
                          value: item.id, child: Text(item.name)))
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (id) {
                          final selected =
                              items.where((item) => item.id == id).firstOrNull;
                          setState(() {
                            _categoryId = selected?.id;
                            _categorySlug = selected?.slug;
                          });
                        },
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(
                  labelText: 'Severity *',
                  helperText:
                      'Urgent flags priority; it does not guarantee emergency response.',
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (value) => setState(() => _severity = value!),
              ),
              if (_severity == 'urgent') ...[
                const SizedBox(height: 8),
                MaterialBanner(
                  content: const Text(
                      'If anyone is in immediate danger, contact emergency services instead of waiting for this report workflow.'),
                  actions: [
                    TextButton(
                        onPressed: () => context.push('/emergency'),
                        child: const Text('Emergency Contacts')),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText:
                      'Describe the waste, scale, nearby landmarks, and any safety concern.',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            title: '2. Location',
            icon: Icons.location_on_rounded,
            children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _useCurrentGps,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Use Current Location'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickOnMap,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Adjust on Map'),
                  ),
                ),
              ]),
              if (_isResolvingAddress) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 10),
                Text(
                  _resolvedAddress == null
                      ? 'Location name unavailable — coordinates saved.'
                      : 'Detected location: $_resolvedAddress',
                  style: const TextStyle(color: Color(0xFF34D399)),
                ),
                Text(
                  '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _locationCtrl,
                maxLength: 500,
                decoration: const InputDecoration(
                    labelText: 'Landmark / location details'),
              ),
              TextField(
                controller: _barangayCtrl,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Barangay (if known)',
                  helperText:
                      'Review this value if it was detected automatically.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            title: '3. Evidence',
            icon: Icons.perm_media_rounded,
            children: [
              const Text(
                'Attach up to 3 photos and 1 optional video (30 seconds maximum). Do not put yourself at risk to collect evidence.',
                style: TextStyle(color: Color(0xFF94A3B8), height: 1.4),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed:
                      _isSubmitting || _photos.length >= 3 ? null : _pickPhotos,
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: Text('Add Photo (${_photos.length}/3)'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isSubmitting || _video != null ? null : _pickVideo,
                  icon: const Icon(Icons.video_camera_back_rounded),
                  label: Text(_video == null ? 'Add Video' : 'Video Added'),
                ),
              ]),
              for (var index = 0; index < _photos.length; index++)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.image_rounded),
                  title: Text(_photos[index].name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Remove photo',
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _photos.removeAt(index)),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              if (_video != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.videocam_rounded),
                  title: Text(_video!.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Remove video',
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _video = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              const Text(
                'Photos: JPEG, PNG, WebP up to 5 MB each. Video: MP4, MOV, WebM up to 25 MB. The server verifies MIME type and size again.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!reportingEnabled)
            const Text(
              'Waste reporting is temporarily disabled by the Tourism Office.',
              style: TextStyle(color: Color(0xFFF59E0B)),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed:
                _isSubmitting || !reportingEnabled || categoryItems.isEmpty
                    ? null
                    : _submitReport,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(_isSubmitting
                ? 'Submitting…'
                : context.tr('submit_waste_report')),
          ),
        ],
      ),
    );
  }

  Widget _intro() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .35)),
        ),
        child: const Row(children: [
          Icon(Icons.cleaning_services_rounded,
              color: Color(0xFFF59E0B), size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Send a location-confirmed environmental report to the Tubigon LGU and follow its resolution timeline.',
              style: TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Future<void> _useCurrentGps() async {
    final success = await ref.read(userLocationProvider.notifier).locate();
    if (!mounted) return;
    final location = ref.read(userLocationProvider);
    if (!success || !location.hasLocation) {
      _message(location.error ?? 'Unable to get the current location.');
      return;
    }
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
    });
    await _reverseGeocode();
  }

  Future<void> _pickOnMap() async {
    final lat = _latitude ?? 9.9515;
    final lng = _longitude ?? 123.9618;
    final result =
        await context.push<Map<String, dynamic>>('/map/pick?lat=$lat&lng=$lng');
    if (!mounted || result == null) return;
    setState(() {
      _latitude = (result['latitude'] as num?)?.toDouble();
      _longitude = (result['longitude'] as num?)?.toDouble();
    });
    await _reverseGeocode();
  }

  Future<void> _reverseGeocode() async {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return;
    setState(() => _isResolvingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (!mounted) return;
      final place = placemarks.firstOrNull;
      final parts = <String?>[
        place?.street,
        place?.subLocality,
        place?.locality,
        place?.administrativeArea,
      ]
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      setState(() {
        _resolvedAddress = parts.isEmpty ? null : parts.join(', ');
        _geocodingSource = place == null ? null : 'device_geocoding';
        if (_barangayCtrl.text.trim().isEmpty &&
            (place?.subLocality?.trim().isNotEmpty ?? false)) {
          _barangayCtrl.text = place!.subLocality!;
        }
        if (_locationCtrl.text.trim().isEmpty && _resolvedAddress != null) {
          _locationCtrl.text = _resolvedAddress!;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedAddress = null;
          _geocodingSource = null;
          if (_locationCtrl.text.trim().isEmpty) {
            _locationCtrl.text = 'Pinned map location';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  Future<ImageSource?> _source(String title) =>
      showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text('Use camera for $title'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ]),
        ),
      );

  Future<void> _pickPhotos() async {
    final source = await _source('a photo');
    if (source == null) return;
    final picked = source == ImageSource.camera
        ? [
            if (await _picker.pickImage(
                    source: source, imageQuality: 88, maxWidth: 1920)
                case final XFile file)
              file,
          ]
        : await _picker.pickMultiImage(imageQuality: 88, maxWidth: 1920);
    for (final file in picked) {
      if (_photos.length >= 3) break;
      if (await _validPhoto(file)) _photos.add(file);
    }
    if (mounted) setState(() {});
  }

  Future<bool> _validPhoto(XFile file) async {
    final extension = file.name.split('.').last.toLowerCase();
    final mime = file.mimeType?.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
        (mime != null &&
            !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime))) {
      if (mounted) _message('${file.name} is not a supported photo.');
      return false;
    }
    if (await file.length() > 5 * 1024 * 1024) {
      if (mounted) _message('${file.name} is larger than 5 MB.');
      return false;
    }
    return true;
  }

  Future<void> _pickVideo() async {
    final source = await _source('a video');
    if (source == null) return;
    final file = await _picker.pickVideo(
        source: source, maxDuration: const Duration(seconds: 30));
    if (file == null || !mounted) return;
    final extension = file.name.split('.').last.toLowerCase();
    final mime = file.mimeType?.toLowerCase();
    if (!const {'mp4', 'mov', 'webm'}.contains(extension) ||
        (mime != null &&
            !const {'video/mp4', 'video/quicktime', 'video/webm'}
                .contains(mime))) {
      _message('Choose an MP4, MOV, or WebM video.');
      return;
    }
    if (await file.length() > 25 * 1024 * 1024) {
      if (mounted) _message('The selected video is larger than 25 MB.');
      return;
    }
    setState(() => _video = file);
  }

  String _friendlyError(Object error) {
    if (error is AppException) return error.message;
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.contains('DioException')
        ? 'The report could not be submitted. Check your connection and retry.'
        : text;
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
