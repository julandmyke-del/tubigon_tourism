import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../map/providers/map_provider.dart';
import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerCreateListingPage extends ConsumerStatefulWidget {
  const PartnerCreateListingPage({super.key, this.listingId});
  final String? listingId;
  @override
  ConsumerState<PartnerCreateListingPage> createState() => _State();
}

class _State extends ConsumerState<PartnerCreateListingPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _hours = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _price = TextEditingController();
  final _capacity = TextEditingController();
  final _duration = TextEditingController();
  String _type = 'tour';
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.listingId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final item = await ref
          .read(tourismPartnerRepositoryProvider)
          .getListingById(widget.listingId!);
      _name.text = item['listing_name']?.toString() ?? '';
      _description.text = item['description']?.toString() ?? '';
      _address.text = item['address']?.toString() ?? '';
      _phone.text = item['contact_number']?.toString() ?? '';
      _email.text = item['email']?.toString() ?? '';
      _hours.text = item['operating_hours']?.toString() ?? '';
      _latitude.text = item['latitude']?.toString() ?? '';
      _longitude.text = item['longitude']?.toString() ?? '';
      _price.text = item['price']?.toString() ?? '';
      _capacity.text = item['capacity']?.toString() ?? '';
      _duration.text = item['duration_minutes']?.toString() ?? '';
      _type = item['listing_type']?.toString() ?? 'tour';
      _loaded = true;
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final item in [
      _name,
      _description,
      _address,
      _phone,
      _email,
      _hours,
      _latitude,
      _longitude,
      _price,
      _capacity,
      _duration
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PartnerTheme.bgDark,
        appBar: AppBar(
          backgroundColor: PartnerTheme.bgDark,
          leading: BackButton(onPressed: () => context.pop()),
          title: Text(widget.listingId == null
              ? 'Create Tourism Listing'
              : 'Edit Tourism Listing'),
        ),
        body: _loading && !_loaded
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: PartnerTheme.cardDecoration(),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Supported listing information',
                              style: PartnerTheme.headingSmall()),
                          const SizedBox(height: 14),
                          _responsive([
                            _field('Listing name', _name, requiredField: true),
                            DropdownButtonFormField<String>(
                              initialValue: _type,
                              dropdownColor: PartnerTheme.cardDark,
                              items: const [
                                DropdownMenuItem(
                                    value: 'tour', child: Text('Tour')),
                                DropdownMenuItem(
                                    value: 'activity', child: Text('Activity')),
                                DropdownMenuItem(
                                    value: 'tour_package',
                                    child: Text('Tour package')),
                                DropdownMenuItem(
                                    value: 'transport_service',
                                    child: Text('Transport service')),
                                DropdownMenuItem(
                                    value: 'guide_service',
                                    child: Text('Guide service')),
                                DropdownMenuItem(
                                    value: 'experience',
                                    child: Text('Experience')),
                              ],
                              onChanged: (value) =>
                                  setState(() => _type = value ?? 'tour'),
                            ),
                            _field('Contact number', _phone),
                            _field('Contact email', _email),
                            _field('Price per guest (optional)', _price,
                                numeric: true),
                            _field('Capacity (optional)', _capacity,
                                numeric: true),
                            _field('Duration in minutes (optional)', _duration,
                                numeric: true),
                            _field('Operating hours', _hours,
                                hint: '08:00-17:00'),
                          ]),
                          const SizedBox(height: 12),
                          _field('Description', _description,
                              requiredField: true, lines: 4),
                          const SizedBox(height: 12),
                          _field('Address', _address, requiredField: true),
                          const SizedBox(height: 12),
                          _responsive([
                            _field('Latitude', _latitude,
                                requiredField: true, numeric: true),
                            _field('Longitude', _longitude,
                                requiredField: true, numeric: true),
                          ]),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                              onPressed: _pickLocation,
                              icon: const Icon(Icons.map_rounded),
                              label: const Text('Set location on Smart Map')),
                          const SizedBox(height: 20),
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            OutlinedButton(
                                onPressed: () => context.pop(),
                                child: const Text('Cancel')),
                            ElevatedButton.icon(
                              onPressed: _loading ? null : _save,
                              icon: _loading
                                  ? const SizedBox.square(
                                      dimension: 15,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.save_rounded),
                              label: Text(widget.listingId == null
                                  ? 'Save draft'
                                  : 'Save changes'),
                            ),
                          ]),
                        ]),
                  ),
                ),
              ),
      );

  Future<void> _pickLocation() async {
    final result = await context.push<Map<String, dynamic>>(
      '/map/pick?mode=place&lat=${double.tryParse(_latitude.text) ?? 9.9515}&lng=${double.tryParse(_longitude.text) ?? 123.9618}',
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude.text = result['latitude']?.toString() ?? '';
      _longitude.text = result['longitude']?.toString() ?? '';
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'listing_name': _name.text.trim(),
        'listing_type': _type,
        'description': _description.text.trim(),
        'address': _address.text.trim(),
        'latitude': double.parse(_latitude.text),
        'longitude': double.parse(_longitude.text),
        'contact_number':
            _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'operating_hours':
            _hours.text.trim().isEmpty ? null : _hours.text.trim(),
        'price': double.tryParse(_price.text),
        'capacity': int.tryParse(_capacity.text),
        'duration_minutes': int.tryParse(_duration.text),
      };
      final repo = ref.read(tourismPartnerRepositoryProvider);
      if (widget.listingId == null) {
        await repo.createListing(payload);
      } else {
        await repo.updateListing(widget.listingId!, payload);
      }
      ref.invalidate(partnerListingsProvider);
      ref.invalidate(partnerDashboardStatsProvider);
      ref.invalidate(mapMarkersProvider);
      if (mounted) {
        _message(widget.listingId == null
            ? 'Listing draft saved.'
            : 'Listing changes saved.');
        context.pop();
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _responsive(List<Widget> children) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 700
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList());
      });

  Widget _field(String label, TextEditingController controller,
          {bool requiredField = false,
          bool numeric = false,
          int lines = 1,
          String? hint}) =>
      TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        validator: requiredField
            ? (value) => (value == null || value.trim().isEmpty)
                ? '$label is required.'
                : null
            : null,
        decoration: InputDecoration(labelText: label, hintText: hint),
      );

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: error ? PartnerTheme.red : PartnerTheme.green,
            content: Text(text)),
      );
}
