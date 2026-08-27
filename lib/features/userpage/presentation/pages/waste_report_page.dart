import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../waste_reporting/repositories/waste_report_repository.dart';
import '../../../map/providers/map_provider.dart';
import '../../../../core/utils/auth_action_guard.dart';

const _categories = [
  'Plastic Waste',
  'Coastal Pollution',
  'Illegal Dumping',
  'Overflowing Bin',
  'Hazardous Material',
  'Other',
];

class WasteReportPage extends ConsumerStatefulWidget {
  const WasteReportPage({super.key});

  @override
  ConsumerState<WasteReportPage> createState() => _WasteReportPageState();
}

class _WasteReportPageState extends ConsumerState<WasteReportPage> {
  String _selectedCategory = 'Plastic Waste';
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isSubmitting = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!await requireSignedIn(context, ref) || !mounted) return;
    final desc = _descCtrl.text.trim();
    if (desc.length < 10 || desc.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Description must be between 10 and 2000 characters.')),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Use GPS or pin the report location on the map.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final synced = await ref.read(wasteReportRepositoryProvider).submitReport(
            category: _selectedCategory,
            description: desc,
            latitude: _latitude,
            longitude: _longitude,
            locationText: _locationCtrl.text.trim().isNotEmpty
                ? _locationCtrl.text.trim()
                : 'Pinned map location',
            localImagePath: null,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor:
            synced ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        content: Text(synced
            ? 'Waste report submitted successfully. Thank you for keeping Tubigon clean!'
            : 'You are offline. The report is saved and pending synchronization.'),
      ));
      context.canPop() ? context.pop() : context.goNamed(RouteNames.home);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report submission failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.home),
        ),
        title: const Text(
          'Report Waste & Issues',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.report_rounded,
                      color: Color(0xFFF59E0B), size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Cleanup Action',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Help LGU Staff locate and resolve waste issues in Tubigon.',
                          style:
                              TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Category Selection
            const Text('Issue Category',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF0F172A),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFFF59E0B)),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Location
            const Text('Location / Landmark',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Near Tubigon Port Boardwalk',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                prefixIcon: const Icon(Icons.location_on_rounded,
                    color: Color(0xFF38BDF8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _useCurrentGps,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Use Current GPS'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickOnMap,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Adjust on Map'),
                  ),
                ),
              ],
            ),
            if (_latitude != null && _longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF34D399), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Location set: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                    style:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ]),
              ),

            const SizedBox(height: 20),

            // Description
            const Text('Issue Description',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'Provide details about the waste accumulation or environmental hazard…',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2))
                  : const Text('Submit Waste Report',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _useCurrentGps() async {
    final success = await ref.read(userLocationProvider.notifier).locate();
    if (!mounted) return;
    final location = ref.read(userLocationProvider);
    if (success && location.hasLocation) {
      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
      });
      if (_locationCtrl.text.trim().isEmpty) {
        _locationCtrl.text = 'Current GPS location';
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(location.error ?? 'Unable to get current location.')),
      );
    }
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
    if (_locationCtrl.text.trim().isEmpty) {
      _locationCtrl.text = 'Pinned map location';
    }
  }
}
