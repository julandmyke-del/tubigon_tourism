import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../map/providers/map_provider.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerListingsPage extends ConsumerStatefulWidget {
  const PartnerListingsPage({super.key});

  @override
  ConsumerState<PartnerListingsPage> createState() =>
      _PartnerDestinationState();
}

class _PartnerDestinationState extends ConsumerState<PartnerListingsPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final assignment = ref.watch(currentPartnerAssignmentProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
        child: assignment.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _StateMessage(
            icon: Icons.cloud_off_rounded,
            title: "We couldn't load your destination.",
            message: 'Check your connection and try again.',
            action: () => ref.invalidate(currentPartnerAssignmentProvider),
          ),
          data: (assignment) {
            if (assignment == null || assignment['destination'] is! Map) {
              return const _StateMessage(
                icon: Icons.assignment_late_outlined,
                title: 'No destination assigned',
                message:
                    'Contact the Tourism Office or wait for an Admin assignment. Creating duplicate public destinations is not available here.',
              );
            }
            final spot = Map<String, dynamic>.from(
              assignment['destination'] as Map,
            );
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(
                currentPartnerAssignmentProvider.future,
              ),
              child: ListView(
                children: [
                  Text('Assigned Destination',
                      style: PartnerTheme.headingLarge()),
                  Text(
                    'Manage the authoritative Tourist Spot assigned to this account.',
                    style: PartnerTheme.label(),
                  ),
                  const SizedBox(height: 18),
                  _DestinationHeader(spot: spot, assignment: assignment),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 850;
                    final cards = [
                      _ContentCard(
                        title: 'Partner editable',
                        icon: Icons.edit_note_rounded,
                        color: PartnerTheme.primaryOrange,
                        body:
                            'Description, visitor information, opening hours, contact information, amenities, and booking instructions.',
                        action: FilledButton.icon(
                          onPressed:
                              _busy ? null : () => _editDestination(spot),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Manage Details'),
                        ),
                      ),
                      _ContentCard(
                        title: 'Municipal controls',
                        icon: Icons.verified_user_outlined,
                        color: PartnerTheme.textMuted,
                        body:
                            'Name, category, assignment, publication, operational status, and map coordinates are controlled by LGU/Admin.',
                        action: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/tourism-partner/preview/${spot['integer_id'] ?? 0}',
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Preview as Tourist'),
                        ),
                      ),
                    ];
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 14),
                              Expanded(child: cards[1]),
                            ],
                          )
                        : Column(
                            children: [
                              cards[0],
                              const SizedBox(height: 12),
                              cards[1]
                            ],
                          );
                  }),
                  const SizedBox(height: 16),
                  _AvailabilityCard(
                    spot: spot,
                    busy: _busy,
                    onChange: () => _changeAvailability(spot),
                  ),
                  const SizedBox(height: 16),
                  _QuickActions(
                    onReservations: () =>
                        context.go('/tourism-partner/reservations'),
                    onMap: () => context.push(
                      '/map?marker=tourist_spot:${spot['id']}',
                    ),
                    onActivity: _showActivity,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _editDestination(Map<String, dynamic> spot) async {
    final controllers = {
      'short_description':
          TextEditingController(text: '${spot['short_description'] ?? ''}'),
      'description':
          TextEditingController(text: '${spot['description'] ?? ''}'),
      'contact_information':
          TextEditingController(text: '${spot['contact_information'] ?? ''}'),
      'opening_hours':
          TextEditingController(text: '${spot['opening_hours'] ?? ''}'),
      'visitor_instructions':
          TextEditingController(text: '${spot['visitor_instructions'] ?? ''}'),
      'booking_instructions':
          TextEditingController(text: '${spot['booking_instructions'] ?? ''}'),
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Manage ${spot['name']}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(controllers['short_description']!, 'Short description',
                    2, 500),
                _field(
                    controllers['description']!, 'Full description', 5, 10000),
                _field(controllers['opening_hours']!,
                    'Opening / visiting hours', 2, 2000),
                _field(controllers['contact_information']!,
                    'Contact information', 2, 2000),
                _field(controllers['visitor_instructions']!,
                    'Visitor and safety reminders', 4, 5000),
                _field(controllers['booking_instructions']!,
                    'Booking instructions', 3, 5000),
              ],
            ),
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
    final payload = {
      for (final entry in controllers.entries)
        entry.key: entry.value.text.trim()
    };
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (save != true || !mounted) return;
    final repository = ref.read(tourismPartnerRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repository.updateManagedDestination(spot['id'].toString(), payload);
      if (!mounted) return;
      _refreshDestination();
      _snack('Destination information updated.');
    } catch (_) {
      if (mounted) {
        _snack("We couldn't save the destination. Try again.", error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
          TextEditingController controller, String label, int lines, int max) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: lines,
          maxLength: max,
          decoration:
              InputDecoration(labelText: label, alignLabelWithHint: true),
        ),
      );

  Future<void> _changeAvailability(Map<String, dynamic> spot) async {
    final enabled =
        spot['booking_enabled'] == true || spot['booking_enabled'] == 1;
    String reasonCode = 'weather_conditions';
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(enabled ? 'Pause reservations?' : 'Resume reservations?'),
          content: enabled
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    initialValue: reasonCode,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: _reasonCodes
                        .map((code) => DropdownMenuItem(
                            value: code, child: Text(_label(code))))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => reasonCode = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: note,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Public note (optional)')),
                ])
              : const Text(
                  'New Tourist reservations will be accepted again. Existing reservations are unchanged.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(enabled ? 'Pause' : 'Resume')),
          ],
        ),
      ),
    );
    final detail = note.text.trim();
    note.dispose();
    if (confirmed != true || !mounted) return;
    final repository = ref.read(tourismPartnerRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repository.updateBookingAvailability(
        spot['id'].toString(),
        enabled: !enabled,
        reasonCode: enabled ? reasonCode : null,
        reason: enabled ? detail : null,
      );
      if (!mounted) return;
      _refreshDestination();
      _snack(enabled ? 'Reservations paused.' : 'Reservations resumed.');
    } catch (_) {
      if (mounted) {
        _snack("We couldn't update booking availability.", error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshDestination() {
    ref.invalidate(currentPartnerAssignmentProvider);
    ref.invalidate(partnerManagedDestinationsProvider);
    ref.invalidate(partnerDashboardStatsProvider);
    ref.invalidate(partnerRecentActivityProvider);
    ref.invalidate(touristSpotsListProvider);
    ref.invalidate(bookableTouristSpotsProvider);
    ref.invalidate(mapMarkersProvider);
  }

  Future<void> _showActivity() async {
    final activity = await ref.read(partnerRecentActivityProvider.future);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: activity.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No destination activity yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activity.length,
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(
                      '${activity[index]['action'] ?? 'Destination update'}'),
                  subtitle: Text('${activity[index]['created_at'] ?? ''}'),
                ),
              ),
      ),
    );
  }

  void _snack(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: error ? PartnerTheme.red : PartnerTheme.green,
            content: Text(message)),
      );

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
  static String _label(String value) => value
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _DestinationHeader extends StatelessWidget {
  const _DestinationHeader({required this.spot, required this.assignment});
  final Map<String, dynamic> spot;
  final Map<String, dynamic> assignment;

  @override
  Widget build(BuildContext context) {
    final category =
        spot['category'] is Map ? (spot['category'] as Map)['name'] : null;
    final image =
        (spot['images'] is List && (spot['images'] as List).isNotEmpty)
            ? (spot['images'] as List).first.toString()
            : null;
    return Container(
      decoration: PartnerTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final cover = Container(
          width: wide ? 250 : double.infinity,
          height: 190,
          color: PartnerTheme.cardDark,
          child: image == null
              ? Icon(Icons.landscape_rounded,
                  size: 58, color: PartnerTheme.textMuted)
              : Image.network(image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined)),
        );
        final details = Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${spot['name'] ?? 'Assigned destination'}',
                style: PartnerTheme.headingLarge()),
            Text(
                '${category ?? 'Tourist Spot'} • ${spot['address'] ?? 'Tubigon, Bohol'}',
                style: PartnerTheme.label()),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip('ASSIGNED', PartnerTheme.green),
              _chip(
                  (spot['is_published'] == true || spot['is_published'] == 1)
                      ? 'PUBLISHED'
                      : 'NOT PUBLISHED',
                  PartnerTheme.primaryOrange),
              _chip('${spot['operational_status'] ?? 'active'}'.toUpperCase(),
                  PartnerTheme.textMuted),
            ]),
            const SizedBox(height: 12),
            Text(
                'Assigned ${assignment['assigned_at'] ?? 'by the Tourism Office'}',
                style: PartnerTheme.label()),
            Text('Last updated ${spot['updated_at'] ?? '—'}',
                style: PartnerTheme.label()),
          ]),
        );
        return wide
            ? Row(children: [cover, Expanded(child: details)])
            : Column(children: [cover, details]);
      }),
    );
  }

  static Widget _chip(String label, Color color) => Chip(
        avatar: Icon(Icons.circle, size: 9, color: color),
        label: Text(label),
      );
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard(
      {required this.spot, required this.busy, required this.onChange});
  final Map<String, dynamic> spot;
  final bool busy;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) {
    final enabled =
        spot['booking_enabled'] == true || spot['booking_enabled'] == 1;
    final supported = spot['is_bookable'] == true || spot['is_bookable'] == 1;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PartnerTheme.cardDecoration(),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reservation Availability',
                  style: PartnerTheme.headingSmall()),
              Text(
                  !supported
                      ? 'Reservations are not configured by LGU'
                      : enabled
                          ? '● Accepting Reservations'
                          : '● Reservations Paused',
                  style: TextStyle(
                      color: enabled ? PartnerTheme.green : PartnerTheme.orange,
                      fontWeight: FontWeight.w800)),
              if (!enabled && spot['booking_unavailable_reason_code'] != null)
                Text(
                    'Reason: ${_PartnerDestinationState._label(spot['booking_unavailable_reason_code'].toString())}',
                    style: PartnerTheme.label()),
              if (!enabled &&
                  '${spot['booking_unavailable_reason'] ?? ''}'.isNotEmpty)
                Text('${spot['booking_unavailable_reason']}',
                    style: PartnerTheme.label()),
            ]),
            FilledButton.icon(
              onPressed: supported && !busy ? onChange : null,
              icon: Icon(enabled
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline),
              label:
                  Text(enabled ? 'Pause Reservations' : 'Resume Reservations'),
            ),
          ]),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.body,
      required this.action});
  final String title;
  final IconData icon;
  final Color color;
  final String body;
  final Widget action;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: PartnerTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title, style: PartnerTheme.headingSmall()),
          const SizedBox(height: 6),
          Text(body, style: PartnerTheme.label()),
          const SizedBox(height: 14),
          action,
        ]),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions(
      {required this.onReservations,
      required this.onMap,
      required this.onActivity});
  final VoidCallback onReservations;
  final VoidCallback onMap;
  final VoidCallback onActivity;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(
            onPressed: onReservations,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('View Reservations')),
        OutlinedButton.icon(
            onPressed: onMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('View on Smart Map')),
        OutlinedButton.icon(
            onPressed: onActivity,
            icon: const Icon(Icons.history_rounded),
            label: const Text('Activity History')),
      ]);
}

class _StateMessage extends StatelessWidget {
  const _StateMessage(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 80),
        Icon(icon, size: 58, color: PartnerTheme.primaryOrange),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center, style: PartnerTheme.headingLarge()),
        const SizedBox(height: 8),
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(message,
                    textAlign: TextAlign.center, style: PartnerTheme.label()))),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(
              child:
                  OutlinedButton(onPressed: action, child: const Text('Retry')))
        ],
      ]);
}
