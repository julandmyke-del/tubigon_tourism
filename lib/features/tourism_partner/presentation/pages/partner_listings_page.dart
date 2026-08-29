import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/tourism_partner_providers.dart';
import '../../../map/providers/map_provider.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../partner_theme.dart';

class PartnerListingsPage extends ConsumerStatefulWidget {
  const PartnerListingsPage({super.key});
  @override
  ConsumerState<PartnerListingsPage> createState() => _State();
}

class _State extends ConsumerState<PartnerListingsPage> {
  String _filter = 'all';
  String _query = '';
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(partnerListingsProvider);
    final managed = ref.watch(partnerManagedDestinationsProvider);
    final managedItems = managed.valueOrNull ?? const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      floatingActionButton: managedItems.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/tourism-partner/listings/create'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create listing'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: listings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(
              error.toString(), () => ref.invalidate(partnerListingsProvider)),
          data: (items) {
            if (managed.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (managed.hasError) {
              return _Message(managed.error.toString(),
                  () => ref.invalidate(partnerManagedDestinationsProvider));
            }
            if (managedItems.isNotEmpty) {
              return _managedDestinations(managedItems);
            }
            final filtered = items.where((item) {
              final status = item['status']?.toString() ?? 'draft';
              final text = '${item['name'] ?? ''} ${item['category'] ?? ''}'
                  .toLowerCase();
              return (_filter == 'all' || status == _filter) &&
                  text.contains(_query.toLowerCase());
            }).toList();
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tourism Listings', style: PartnerTheme.headingLarge()),
                  Text(
                      'Draft, submit, and track municipal review from one place.',
                      style: PartnerTheme.label()),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search listings'),
                      ),
                    ),
                    for (final status in const [
                      'all',
                      'draft',
                      'submitted',
                      'approved',
                      'needs_changes',
                      'suspended',
                      'archived'
                    ])
                      ChoiceChip(
                        label: Text(status.replaceAll('_', ' ')),
                        selected: _filter == status,
                        onSelected: (_) => setState(() => _filter = status),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No listings match this view.',
                                style:
                                    TextStyle(color: PartnerTheme.textMuted)))
                        : RefreshIndicator(
                            onRefresh: () async =>
                                ref.refresh(partnerListingsProvider.future),
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _listingCard(filtered[index]),
                            ),
                          ),
                  ),
                ]);
          },
        ),
      ),
    );
  }

  Widget _managedDestinations(List<Map<String, dynamic>> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Managed Destinations', style: PartnerTheme.headingLarge()),
          Text(
            'Edit the authoritative Tourist Spot record assigned to this account.',
            style: PartnerTheme.label(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(partnerManagedDestinationsProvider.future),
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _managedDestinationCard(items[index]),
              ),
            ),
          ),
        ],
      );

  Widget _managedDestinationCard(Map<String, dynamic> spot) {
    final enabled =
        spot['booking_enabled'] == true || spot['booking_enabled'] == 1;
    final supported = spot['is_bookable'] == true || spot['is_bookable'] == 1;
    final reason =
        _reasonLabel(spot['booking_unavailable_reason_code']?.toString());
    final detail = spot['booking_unavailable_reason']?.toString().trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spot['name']?.toString() ?? 'Managed destination',
                      style: PartnerTheme.headingSmall()),
                  Text(
                    '${spot['is_published'] == true || spot['is_published'] == 1 ? 'Published' : 'Not published'} · ${spot['is_featured'] == true || spot['is_featured'] == 1 ? 'Featured' : 'Standard'}',
                    style: PartnerTheme.label(),
                  ),
                ],
              ),
            ),
            Chip(
              avatar: Icon(
                enabled ? Icons.event_available : Icons.event_busy,
                size: 18,
                color: enabled ? PartnerTheme.green : PartnerTheme.red,
              ),
              label: Text(enabled
                  ? 'ACCEPTING RESERVATIONS'
                  : 'TEMPORARILY UNAVAILABLE'),
            ),
          ],
        ),
        if (!enabled) ...[
          const SizedBox(height: 10),
          Text('Reason: $reason',
              style: const TextStyle(
                  color: PartnerTheme.orange, fontWeight: FontWeight.w700)),
          if (detail.isNotEmpty)
            Text(detail, style: const TextStyle(color: PartnerTheme.textMuted)),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => _editDestination(spot),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit Destination'),
          ),
          ElevatedButton.icon(
            onPressed:
                supported ? () => _changeAvailability(spot, enabled) : null,
            icon: Icon(enabled ? Icons.pause_circle : Icons.play_circle),
            label: Text(enabled ? 'Disable Booking' : 'Enable Booking'),
          ),
        ]),
      ]),
    );
  }

  Future<void> _editDestination(Map<String, dynamic> spot) async {
    final shortDescription = TextEditingController(
        text: spot['short_description']?.toString() ?? '');
    final description =
        TextEditingController(text: spot['description']?.toString() ?? '');
    final contact = TextEditingController(
        text: spot['contact_information']?.toString() ?? '');
    final opening =
        TextEditingController(text: spot['opening_hours']?.toString() ?? '');
    final instructions = TextEditingController(
        text: spot['visitor_instructions']?.toString() ?? '');
    final booking = TextEditingController(
        text: spot['booking_instructions']?.toString() ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit ${spot['name']}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: shortDescription,
                  maxLength: 500,
                  decoration:
                      const InputDecoration(labelText: 'Short description')),
              TextField(
                  controller: description,
                  maxLines: 5,
                  decoration:
                      const InputDecoration(labelText: 'Full description')),
              TextField(
                  controller: contact,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Contact information')),
              TextField(
                  controller: opening,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Opening information')),
              TextField(
                  controller: instructions,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Visitor instructions')),
              TextField(
                  controller: booking,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Booking instructions')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (save != true || !mounted) return;
    try {
      await ref.read(tourismPartnerRepositoryProvider).updateManagedDestination(
        spot['id'].toString(),
        {
          'short_description': shortDescription.text.trim(),
          'description': description.text.trim(),
          'contact_information': contact.text.trim(),
          'opening_hours': opening.text.trim(),
          'visitor_instructions': instructions.text.trim(),
          'booking_instructions': booking.text.trim(),
        },
      );
      _invalidateDestinationData();
      if (mounted) _snack('Destination information updated.');
    } catch (error) {
      if (mounted) _snack(error.toString(), error: true);
    }
  }

  Future<void> _changeAvailability(
      Map<String, dynamic> spot, bool currentlyEnabled) async {
    String reasonCode = 'weather_conditions';
    final detail = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(currentlyEnabled
              ? 'Disable Booking?'
              : 'Resume accepting reservations?'),
          content: currentlyEnabled
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    initialValue: reasonCode,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: _reasonCodes
                        .map((code) => DropdownMenuItem(
                            value: code, child: Text(_reasonLabel(code))))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => reasonCode = value!),
                  ),
                  TextField(
                    controller: detail,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Details (optional)'),
                  ),
                ])
              : const Text('This destination will accept new reservations.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(currentlyEnabled ? 'Disable' : 'Enable')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(tourismPartnerRepositoryProvider)
          .updateBookingAvailability(
            spot['id'].toString(),
            enabled: !currentlyEnabled,
            reasonCode: currentlyEnabled ? reasonCode : null,
            reason: currentlyEnabled ? detail.text : null,
          );
      _invalidateDestinationData();
      if (mounted) {
        _snack(currentlyEnabled
            ? 'Booking disabled with a public reason.'
            : 'Booking is accepting reservations again.');
      }
    } catch (error) {
      if (mounted) _snack(error.toString(), error: true);
    }
  }

  void _invalidateDestinationData() {
    ref.invalidate(partnerManagedDestinationsProvider);
    ref.invalidate(partnerDashboardStatsProvider);
    ref.invalidate(touristSpotsListProvider);
    ref.invalidate(bookableTouristSpotsProvider);
    ref.invalidate(mapMarkersProvider);
  }

  static const _reasonCodes = [
    'weather_conditions',
    'maintenance',
    'fully_booked',
    'temporarily_closed',
    'unsafe_sea_conditions',
    'private_event',
    'seasonal_closure',
    'capacity_reached',
    'site_rehabilitation',
    'other',
  ];

  static String _reasonLabel(String? code) =>
      (code ?? 'temporarily_unavailable')
          .split('_')
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');

  Widget _listingCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'draft';
    final canSubmit = ['draft', 'needs_changes', 'rejected'].contains(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PartnerTheme.cardDecoration(),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 430,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name']?.toString() ?? 'Untitled listing',
                  style: PartnerTheme.headingSmall()),
              Text(
                  '${item['category'] ?? 'Tourism service'} • ${item['location'] ?? 'Location not set'}',
                  style: PartnerTheme.label()),
              const SizedBox(height: 6),
              Chip(label: Text(status.replaceAll('_', ' ').toUpperCase())),
              if ((item['review_notes']?.toString() ?? '').isNotEmpty)
                Text(item['review_notes'].toString(),
                    style: const TextStyle(color: PartnerTheme.orange)),
            ]),
          ),
          Wrap(spacing: 8, children: [
            IconButton(
              tooltip: 'Preview on Smart Map',
              onPressed: () => context.push('/map?marker=tourism_listing:$id'),
              icon: const Icon(Icons.visibility_rounded),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: () =>
                  context.push('/tourism-partner/listings/create?edit=$id'),
              icon: const Icon(Icons.edit_rounded),
            ),
            if (canSubmit)
              ElevatedButton.icon(
                onPressed: _busyId == id ? null : () => _submit(id),
                icon: _busyId == id
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: const Text('Submit'),
              ),
          ]),
        ],
      ),
    );
  }

  Future<void> _submit(String id) async {
    setState(() => _busyId = id);
    try {
      await ref.read(tourismPartnerRepositoryProvider).submitListing(id);
      ref.invalidate(partnerListingsProvider);
      ref.invalidate(partnerDashboardStatsProvider);
      if (mounted) _snack('Listing submitted for review.');
    } catch (error) {
      if (mounted) _snack(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _snack(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: error ? Colors.red : Colors.green,
            content: Text(message)),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.message, this.retry);
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, style: const TextStyle(color: Colors.red)),
        OutlinedButton(onPressed: retry, child: const Text('Retry')),
      ]));
}
