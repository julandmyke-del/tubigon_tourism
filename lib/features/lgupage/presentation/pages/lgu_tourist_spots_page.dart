import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../map/providers/map_provider.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../../providers/lgu_providers.dart';
import '../../../../core/widgets/tourist_spot_booking_dialog.dart';

class LguTouristSpotsPage extends ConsumerWidget {
  const LguTouristSpotsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              'LGU staff can activate, place under maintenance, or archive existing spots.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 14),
          Expanded(
              child: spots.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton(
                    onPressed: () => ref.invalidate(lguTouristSpotsProvider),
                    child: Text('Retry: $error'))),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('No tourist spots configured.',
                        style: TextStyle(color: AppColors.grey400)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final active =
                          item['is_active'] == true || item['is_active'] == 1;
                      final bookingEnabled = item['booking_enabled'] == true ||
                          item['booking_enabled'] == 1;
                      final actor = item['booking_availability_updated_by'];
                      final reason = _reasonLabel(
                          item['booking_unavailable_reason_code']?.toString());
                      return ListTile(
                        tileColor: const Color(0xFF1C2541),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        leading: Icon(Icons.place_rounded,
                            color:
                                active ? AppColors.success : AppColors.warning),
                        title: Text(item['name']?.toString() ?? 'Tourist spot',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${item['address'] ?? 'No address'} • ${active ? 'Active' : 'Inactive'}\n'
                            'Booking: ${bookingEnabled ? 'Accepting reservations' : 'Unavailable — $reason'}'
                            '${actor is Map ? '\nSet by: ${actor['name'] ?? 'Authorized user'}' : ''}',
                            style: const TextStyle(color: AppColors.grey400)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit destination descriptions',
                              onPressed: () => _edit(context, ref, item),
                              icon: const Icon(Icons.edit_note_rounded,
                                  color: AppColors.info),
                            ),
                            IconButton(
                              tooltip: 'Configure booking',
                              onPressed: () => _booking(context, ref, item),
                              icon: Icon(
                                Icons.event_available_rounded,
                                color: item['is_bookable'] == true ||
                                        item['is_bookable'] == 1
                                    ? AppColors.success
                                    : AppColors.grey400,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Manage live booking availability',
                              onPressed: () => _availability(
                                  context, ref, item, bookingEnabled),
                              icon: Icon(
                                bookingEnabled
                                    ? Icons.toggle_on_rounded
                                    : Icons.toggle_off_rounded,
                                color: bookingEnabled
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (status) => _update(
                                  context, ref, item['id'].toString(), status),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'active', child: Text('Activate')),
                                PopupMenuItem(
                                    value: 'maintenance',
                                    child: Text('Maintenance')),
                                PopupMenuItem(
                                    value: 'archived', child: Text('Archive')),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          )),
        ]),
      ),
    );
  }

  Future<void> _update(
      BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(lguRepositoryProvider).updateSpotStatus(id, status);
      ref.invalidate(lguTouristSpotsProvider);
      ref.invalidate(lguDashboardStatsProvider);
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
      ref.invalidate(lguTouristSpotsProvider);
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
      ref.invalidate(lguTouristSpotsProvider);
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
        },
      );
      ref.invalidate(lguTouristSpotsProvider);
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
    }
  }
}
