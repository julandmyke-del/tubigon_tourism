import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../map/providers/map_provider.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../../providers/lgu_providers.dart';
import '../../../../core/widgets/tourist_spot_booking_dialog.dart';

class LguTouristSpotsPage extends ConsumerStatefulWidget {
  const LguTouristSpotsPage({super.key});

  @override
  ConsumerState<LguTouristSpotsPage> createState() =>
      _LguTouristSpotsPageState();
}

class _LguTouristSpotsPageState extends ConsumerState<LguTouristSpotsPage> {
  String _query = '';
  String _statusFilter = 'all';
  String _bookingFilter = 'all';
  String _partnerFilter = 'all';
  String _sort = 'recent';

  @override
  Widget build(BuildContext context) {
    final spots = ref.watch(lguTouristSpotsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tourist Spot Monitoring',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold)),
          const Text(
              'Monitor authoritative destination status, partner assignments, maps, and booking availability.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
              width: 280,
              child: TextField(
                decoration: const InputDecoration(
                    labelText: 'Search name or address',
                    prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            _filter(
                'Status',
                _statusFilter,
                const ['all', 'active', 'maintenance', 'inactive'],
                (value) => setState(() => _statusFilter = value)),
            _filter('Booking', _bookingFilter, const ['all', 'open', 'closed'],
                (value) => setState(() => _bookingFilter = value)),
            _filter(
                'Partner',
                _partnerFilter,
                const ['all', 'assigned', 'unassigned'],
                (value) => setState(() => _partnerFilter = value)),
            _filter(
                'Sort',
                _sort,
                const ['recent', 'name', 'status', 'booking'],
                (value) => setState(() => _sort = value)),
          ]),
          const SizedBox(height: 14),
          Expanded(
              child: spots.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton(
                    onPressed: () => ref.invalidate(lguTouristSpotsProvider),
                    child: Text('Retry: $error'))),
            data: (items) {
              final filtered = items.where(_matches).toList()..sort(_compare);
              return filtered.isEmpty
                  ? const Center(
                      child: Text('No tourist spots configured.',
                          style: TextStyle(color: AppColors.grey400)))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final active = _spotStatus(item) == 'active';
                        final bookingEnabled =
                            item['booking_enabled'] == true ||
                                item['booking_enabled'] == 1;
                        final actor = item['booking_availability_updated_by'];
                        final assignments =
                            item['partner_assignments'] as List? ?? const [];
                        final partnerLabel = assignments.isEmpty
                            ? 'No partner assigned'
                            : ((assignments.first as Map?)?['partner_profile']
                                        as Map?)?['name']
                                    ?.toString() ??
                                'Assigned partner';
                        final reason = _reasonLabel(
                            item['booking_unavailable_reason_code']
                                ?.toString());
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            tileColor: const Color(0xFF1C2541),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            leading: Icon(Icons.place_rounded,
                                color: active
                                    ? AppColors.success
                                    : AppColors.warning),
                            title: Text(
                                item['name']?.toString() ?? 'Tourist spot',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${item['address'] ?? 'No address'} • ${_label(_spotStatus(item))}\n'
                                'Booking: ${bookingEnabled ? 'Accepting reservations' : 'Unavailable — $reason'}'
                                '${actor is Map ? '\nSet by: ${actor['name'] ?? 'Authorized user'}' : ''}'
                                '\nPartner: $partnerLabel',
                                style:
                                    const TextStyle(color: AppColors.grey400)),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Destination actions',
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _edit(context, ref, item);
                                } else if (action == 'map') {
                                  context.push(
                                      '/map?marker=tourist_spot:${item['id']}');
                                } else if (action == 'reservations') {
                                  context.go('/lgu/reservations');
                                } else if (action == 'booking') {
                                  _booking(context, ref, item);
                                } else if (action == 'availability') {
                                  _availability(
                                      context, ref, item, bookingEnabled);
                                } else {
                                  _update(context, ref, item['id'].toString(),
                                      action);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Text('View / edit details')),
                                PopupMenuItem(
                                    value: 'map', child: Text('View on map')),
                                PopupMenuItem(
                                    value: 'reservations',
                                    child: Text('View reservations')),
                                PopupMenuItem(
                                    value: 'booking',
                                    child: Text('Configure booking rules')),
                                PopupMenuItem(
                                    value: 'availability',
                                    child: Text('Manage live availability')),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                    value: 'active', child: Text('Set active')),
                                PopupMenuItem(
                                    value: 'maintenance',
                                    child: Text('Set maintenance')),
                                PopupMenuItem(
                                    value: 'inactive',
                                    child: Text('Set inactive')),
                              ],
                            ),
                          ),
                        );
                      },
                    );
            },
          )),
        ]),
      ),
    );
  }

  Widget _filter(String label, String value, List<String> values,
          ValueChanged<String> onChanged) =>
      SizedBox(
        width: 165,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(_label(item))))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );

  bool _matches(Map<String, dynamic> item) {
    final status = _spotStatus(item);
    final booking =
        item['booking_enabled'] == true || item['booking_enabled'] == 1;
    final assigned =
        (item['partner_assignments'] as List? ?? const []).isNotEmpty;
    final haystack =
        '${item['name'] ?? ''} ${item['address'] ?? ''}'.toLowerCase();
    return haystack.contains(_query) &&
        (_statusFilter == 'all' || status == _statusFilter) &&
        (_bookingFilter == 'all' || (_bookingFilter == 'open') == booking) &&
        (_partnerFilter == 'all' || (_partnerFilter == 'assigned') == assigned);
  }

  int _compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (_sort == 'name') return '${a['name']}'.compareTo('${b['name']}');
    if (_sort == 'status') return _spotStatus(a).compareTo(_spotStatus(b));
    if (_sort == 'booking') {
      final left = a['booking_enabled'] == true || a['booking_enabled'] == 1;
      final right = b['booking_enabled'] == true || b['booking_enabled'] == 1;
      return right.toString().compareTo(left.toString());
    }
    return '${b['updated_at'] ?? ''}'.compareTo('${a['updated_at'] ?? ''}');
  }

  static String _spotStatus(Map<String, dynamic> item) =>
      item['operational_status']?.toString() ??
      ((item['is_active'] == true || item['is_active'] == 1)
          ? 'active'
          : 'inactive');

  static String _label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Future<void> _update(
      BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(lguRepositoryProvider).updateSpotStatus(id, status);
      if (!context.mounted) return;
      ref.invalidate(lguTouristSpotsProvider);
      ref.invalidate(lguDashboardStatsProvider);
      ref.invalidate(lguActivityProvider);
      ref.invalidate(lguAnalyticsProvider);
      ref.invalidate(lguReportsProvider);
      ref.invalidate(touristSpotsListProvider);
      ref.invalidate(bookableTouristSpotsProvider);
      ref.invalidate(mapMarkersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Tourist spot set to $status.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.error, content: Text(error.toString())));
      }
    }
  }

  Future<void> _booking(
      BuildContext context, WidgetRef ref, Map<String, dynamic> spot) async {
    final configuration = await showTouristSpotBookingDialog(context, spot);
    if (configuration == null) return;
    try {
      await ref.read(lguRepositoryProvider).updateTouristSpotBooking(
            spot['id'].toString(),
            configuration,
          );
      if (!context.mounted) return;
      ref.invalidate(lguTouristSpotsProvider);
      ref.invalidate(lguActivityProvider);
      ref.invalidate(lguAnalyticsProvider);
      ref.invalidate(lguReportsProvider);
      ref.invalidate(touristSpotsListProvider);
      ref.invalidate(bookableTouristSpotsProvider);
      ref.invalidate(mapMarkersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Booking configuration updated.'),
        ));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _availability(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> spot,
    bool currentlyEnabled,
  ) async {
    var reasonCode = 'weather_conditions';
    final detail = TextEditingController(
        text: spot['booking_unavailable_reason']?.toString() ?? '');
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
              : const Text(
                  'This destination will accept new reservations again.'),
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
    final detailText = detail.text;
    detail.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(lguRepositoryProvider)
          .updateTouristSpotBookingAvailability(
            spot['id'].toString(),
            enabled: !currentlyEnabled,
            reasonCode: currentlyEnabled ? reasonCode : null,
            reason: currentlyEnabled ? detailText : null,
          );
      if (!context.mounted) return;
      ref.invalidate(lguTouristSpotsProvider);
      ref.invalidate(lguActivityProvider);
      ref.invalidate(lguAnalyticsProvider);
      ref.invalidate(lguReportsProvider);
      ref.invalidate(touristSpotsListProvider);
      ref.invalidate(bookableTouristSpotsProvider);
      ref.invalidate(mapMarkersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.success,
          content: Text(currentlyEnabled
              ? 'Booking disabled with a public reason.'
              : 'Booking enabled.'),
        ));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text(error.toString()),
        ));
      }
    }
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

  static String _reasonLabel(String? code) {
    final value = code?.trim();
    if (value == null || value.isEmpty) return 'Temporarily unavailable';
    return value
        .split('_')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Map<String, dynamic> spot) async {
    final shortDescription = TextEditingController(
        text: spot['short_description']?.toString() ?? '');
    final description =
        TextEditingController(text: spot['description']?.toString() ?? '');
    final aliases = TextEditingController(
      text: spot['aliases'] is List ? (spot['aliases'] as List).join(', ') : '',
    );
    final latitude =
        TextEditingController(text: spot['latitude']?.toString() ?? '');
    final longitude =
        TextEditingController(text: spot['longitude']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: Text('Edit ${spot['name'] ?? 'destination'}',
            style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: shortDescription,
                  maxLength: 500,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Short description'),
                ),
                TextFormField(
                  controller: description,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Full description'),
                ),
                TextFormField(
                  controller: aliases,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Search aliases (comma-separated)'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: latitude,
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return longitude.text.trim().isEmpty
                              ? null
                              : 'Required with longitude';
                        }
                        final parsed = double.tryParse(text);
                        return parsed == null || parsed < -90 || parsed > 90
                            ? 'Use -90 to 90'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: longitude,
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return latitude.text.trim().isEmpty
                              ? null
                              : 'Required with latitude';
                        }
                        final parsed = double.tryParse(text);
                        return parsed == null || parsed < -180 || parsed > 180
                            ? 'Use -180 to 180'
                            : null;
                      },
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save')),
        ],
      ),
    );
    if (save != true) {
      shortDescription.dispose();
      description.dispose();
      aliases.dispose();
      latitude.dispose();
      longitude.dispose();
      return;
    }

    try {
      await ref.read(lguRepositoryProvider).updateTouristSpot(
        spot['id'].toString(),
        {
          'short_description': shortDescription.text.trim(),
          'description': description.text.trim(),
          'aliases': aliases.text
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(),
          'latitude': latitude.text.trim().isEmpty
              ? null
              : double.parse(latitude.text.trim()),
          'longitude': longitude.text.trim().isEmpty
              ? null
              : double.parse(longitude.text.trim()),
        },
      );
      if (!context.mounted) return;
      ref.invalidate(lguTouristSpotsProvider);
      ref.invalidate(lguActivityProvider);
      ref.invalidate(touristSpotsListProvider);
      ref.invalidate(mapMarkersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Destination descriptions updated.'),
        ));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      shortDescription.dispose();
      description.dispose();
      aliases.dispose();
      latitude.dispose();
      longitude.dispose();
    }
  }
}
