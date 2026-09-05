import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';
import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../itinerary/repositories/itinerary_repository.dart';
import '../../../map/providers/map_provider.dart';
import '../../../map/map_focus.dart';
import '../../../msmepage/models/msme.dart';
import '../../../msmepage/repositories/msme_repository.dart';
import '../../../notifications/repositories/notification_repository.dart';
import '../../../reservations/models/reservation.dart';
import '../../../reservations/repositories/reservation_repository.dart';
import '../../../settings/repositories/settings_repository.dart';
import '../../../tourist_spots/models/tourist_spot.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';

class CreateReservationPage extends ConsumerStatefulWidget {
  const CreateReservationPage({
    super.key,
    this.initialSpotUuid,
    this.initialReservableType = 'spot',
    this.initialReservableId,
    this.initialName,
    this.initialPrice,
  });

  final String? initialSpotUuid;
  final String initialReservableType;
  final String? initialReservableId;
  final String? initialName;
  final double? initialPrice;

  @override
  ConsumerState<CreateReservationPage> createState() =>
      _CreateReservationPageState();
}

class _CreateReservationPageState extends ConsumerState<CreateReservationPage> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String? _selectedSlot;
  String? _selectedSpotUuid;
  int _guests = 1;
  bool _isSubmitting = false;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSpotUuid = widget.initialReservableId ?? widget.initialSpotUuid;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _dateValue =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(TouristSpot? spot, Msme? msme) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final maximum = today.add(
      Duration(days: spot?.advanceBookingDays ?? 365),
    );
    bool selectable(DateTime date) => msme?.isAvailableOn(date) ?? true;
    var initial = _selectedDate.isAfter(maximum) ? maximum : _selectedDate;
    initial = DateUtils.dateOnly(initial);
    while (!initial.isAfter(maximum) && !selectable(initial)) {
      initial = initial.add(const Duration(days: 1));
    }
    if (initial.isAfter(maximum)) {
      _message('This business has no selectable dates in the booking window.');
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: maximum,
      selectableDayPredicate: selectable,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  Future<void> _submit(TouristSpot? spot, Msme? msme) async {
    final targetId = _selectedSpotUuid;
    if (targetId == null || targetId.isEmpty) return;
    if (widget.initialReservableType == 'spot') {
      if (spot == null || !spot.canAcceptBookings) {
        _message(spot == null
            ? 'Reservations are not enabled for this destination.'
            : 'Booking is currently unavailable. Reason: ${spot.bookingUnavailableLabel}${spot.bookingUnavailableReason?.trim().isNotEmpty == true ? ' — ${spot.bookingUnavailableReason}' : ''}');
        return;
      }
      if (spot.maxGuestsPerReservation != null &&
          _guests > spot.maxGuestsPerReservation!) {
        _message('The maximum is ${spot.maxGuestsPerReservation} guests.');
        return;
      }
      if (spot.bookingMode == 'date_time_slot' && _selectedSlot == null) {
        _message('Select a configured time slot.');
        return;
      }
    } else if (widget.initialReservableType == 'msme' &&
        (msme == null || !msme.isAvailableOn(_selectedDate))) {
      _message(
          'This business is unavailable on the selected date. Choose an available date.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit reservation?'),
        content: Text(
          'Request $_guests guest(s) for $_dateValue${_displayTime(spot) == null ? '' : ' at ${_displayTime(spot)}'}? Laravel will verify availability before saving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final reservation =
          await ref.read(reservationRepositoryProvider).createReservation(
                reservableType: widget.initialReservableType,
                reservableId: targetId,
                date: _dateValue,
                startTime: _serverTime(spot),
                guests: _guests,
                notes: _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
              );
      ref.invalidate(reservationsListProvider);
      ref.invalidate(touristNotificationsProvider);
      ref.invalidate(touristUnreadCountProvider);
      ref.invalidate(touristSpotsListProvider);
      ref.invalidate(bookableTouristSpotsProvider);
      ref.invalidate(mapMarkersProvider);
      ref.invalidate(itinerariesProvider);
      if (!mounted) return;
      await _showSuccess(reservation, spot);
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _serverTime(TouristSpot? spot) {
    if (widget.initialReservableType == 'spot') {
      return spot?.bookingMode == 'date_time_slot' ? _selectedSlot : null;
    }
    return '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
  }

  String? _displayTime(TouristSpot? spot) => _serverTime(spot);

  Future<void> _showSuccess(Reservation reservation, TouristSpot? spot) async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded,
            color: Color(0xFF10B981), size: 44),
        title: const Text('Reservation submitted successfully.'),
        content: Text(
          '${reservation.publicReference.isEmpty ? reservation.id : reservation.publicReference}\n${reservation.spotName}\n$_dateValue\nStatus: Pending',
        ),
        actions: [
          if (spot != null && spot.latitude != 0 && spot.longitude != 0)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'map'),
              child: const Text('View on Map'),
            ),
          if (spot != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'itinerary'),
              child: const Text('Add to Itinerary'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'reservation'),
            child: const Text('View Reservation'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'map' && spot != null) {
      context.go(mapFocusPathForEntity(
        entityType: 'tourist_spot',
        entityId: spot.uuid,
      ));
    } else if (action == 'itinerary' && spot != null) {
      await showAddToItinerarySheet(
        context,
        ref,
        _markerFor(spot),
        reservationId: reservation.id,
      );
      if (mounted) context.go('/reservations/${reservation.id}');
    } else {
      context.go('/reservations/${reservation.id}');
    }
  }

  MapMarker _markerFor(TouristSpot spot) => MapMarker(
        id: 'tourist_spot:${spot.uuid}',
        sourceId: spot.uuid,
        sourceIntegerId: spot.id,
        name: spot.name,
        description: spot.description,
        address: spot.address,
        latitude: spot.latitude,
        longitude: spot.longitude,
        category: MapMarkerCategory.touristSpot,
        categoryName: spot.categoryName,
        images: spot.images,
        isFeatured: spot.isFeatured,
        isBookable: spot.isBookable,
        bookingEnabled: spot.bookingEnabled,
        bookingUnavailableReasonCode: spot.bookingUnavailableReasonCode,
        bookingUnavailableReason: spot.bookingUnavailableReason,
      );

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final globalBookingEnabled = ref
            .watch(systemSettingsProvider)
            .valueOrNull?['global_booking_enabled'] !=
        false;
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      return signedInRequiredPage(context, ref, title: 'New Booking');
    }
    final AsyncValue<List<TouristSpot>> spotsAsync =
        widget.initialReservableType == 'spot'
            ? ref.watch(bookableTouristSpotsProvider)
            : const AsyncData([]);
    final AsyncValue<List<Msme>> msmesAsync =
        widget.initialReservableType == 'msme'
            ? ref.watch(msmeListProvider)
            : const AsyncData([]);
    if (msmesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (msmesAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Booking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'Business availability could not be loaded. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(msmeListProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ]),
          ),
        ),
      );
    }
    Msme? selectedMsme;
    if (widget.initialReservableType == 'msme' && _selectedSpotUuid != null) {
      for (final msme in msmesAsync.valueOrNull ?? const <Msme>[]) {
        if (msme.uuid == _selectedSpotUuid) selectedMsme = msme;
      }
    }
    return spotsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('New Booking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Booking destinations could not be loaded. Check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(bookableTouristSpotsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (spots) {
        final bookable = spots;
        TouristSpot? selectedSpot;
        if (widget.initialReservableType == 'spot' &&
            _selectedSpotUuid != null) {
          for (final spot in spots) {
            if (spot.uuid == _selectedSpotUuid) selectedSpot = spot;
          }
        }
        return _buildForm(
            bookable, selectedSpot, selectedMsme, globalBookingEnabled);
      },
    );
  }

  Widget _buildForm(List<TouristSpot> bookable, TouristSpot? spot, Msme? msme,
      bool globalBookingEnabled) {
    final isSpot = widget.initialReservableType == 'spot';
    final availability = isSpot && spot?.canAcceptBookings == true
        ? ref.watch(touristSpotAvailabilityProvider(
            (spotId: spot!.uuid, date: _dateValue)))
        : null;
    final availabilityData = availability?.valueOrNull;
    final slotOptions =
        (availabilityData?['slots'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['available'] == true)
            .toList(growable: false);
    final serverAvailable = !isSpot ||
        (availabilityData != null && availabilityData['available'] == true);
    final fee = isSpot ? spot?.reservationFee : widget.initialPrice;
    final fixedName = isSpot ? spot?.name : widget.initialName;
    final unavailable = isSpot &&
        _selectedSpotUuid != null &&
        (spot == null || !spot.canAcceptBookings);
    final msmeDateUnavailable = widget.initialReservableType == 'msme' &&
        (msme == null || !msme.isAvailableOn(_selectedDate));
    final guestLimit = spot?.maxGuestsPerReservation ?? 100;
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(title: const Text('New Booking')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Destination', style: _labelStyle),
          const SizedBox(height: 8),
          if (_selectedSpotUuid != null || !isSpot)
            _panel(Text(fixedName ?? 'Selected destination',
                style: const TextStyle(color: Colors.white)))
          else if (bookable.isEmpty)
            _panel(const Text(
                'Reservations are not currently offered for any published destination.',
                style: TextStyle(color: Color(0xFFCBD5E1))))
          else
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF0F172A),
              items: bookable
                  .map((item) => DropdownMenuItem(
                      value: item.uuid,
                      enabled: item.canAcceptBookings,
                      child: Text(item.canAcceptBookings
                          ? item.name
                          : '${item.name} — Unavailable: ${item.bookingUnavailableLabel}')))
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedSpotUuid = value;
                _selectedSlot = null;
                _guests = 1;
              }),
              decoration:
                  const InputDecoration(labelText: 'Bookable destination'),
            ),
          if (unavailable) ...[
            const SizedBox(height: 12),
            Text(
              'Booking Temporarily Unavailable\nReason: ${spot?.bookingUnavailableLabel ?? 'Destination unavailable'}${spot?.bookingUnavailableReason?.trim().isNotEmpty == true ? '\n${spot!.bookingUnavailableReason}' : ''}',
              style: const TextStyle(color: Color(0xFFFCA5A5)),
            ),
          ],
          if (msmeDateUnavailable) ...[
            const SizedBox(height: 12),
            const Text(
              'This business is closed or unavailable on the selected date.',
              style: TextStyle(color: Color(0xFFFCA5A5)),
            ),
          ],
          if (spot?.bookingAvailableDays.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text('Opening days: ${spot!.bookingAvailableDays.join(', ')}',
                style: const TextStyle(color: Color(0xFF94A3B8))),
          ],
          const SizedBox(height: 20),
          const Text('Reservation date', style: _labelStyle),
          const SizedBox(height: 8),
          _panel(ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_rounded,
                color: Color(0xFFF59E0B)),
            title:
                Text(_dateValue, style: const TextStyle(color: Colors.white)),
            onTap: () => _pickDate(spot, msme),
          )),
          if (availability?.isLoading == true) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (availability?.hasError == true) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(
                child: Text(
                  'This date is unavailable or availability could not be verified.',
                  style: TextStyle(color: Color(0xFFFCA5A5)),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(touristSpotAvailabilityProvider(
                    (spotId: spot!.uuid, date: _dateValue))),
                child: const Text('Retry'),
              ),
            ]),
          ],
          if (availabilityData?['remaining_capacity'] != null) ...[
            const SizedBox(height: 8),
            Text(
              '${availabilityData!['remaining_capacity']} guest spaces remain for this date.',
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
          if (isSpot && spot?.bookingMode == 'date_time_slot') ...[
            const SizedBox(height: 20),
            const Text('Configured time slot', style: _labelStyle),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedSlot,
              dropdownColor: const Color(0xFF0F172A),
              items: slotOptions.map((slot) {
                final start = slot['start']?.toString() ?? '';
                final end = slot['end']?.toString();
                final remaining = slot['remaining_capacity'];
                return DropdownMenuItem(
                  value: start,
                  child: Text(
                    '${end == null ? start : '$start – $end'}${remaining == null ? '' : ' · $remaining left'}',
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedSlot = value),
              decoration: const InputDecoration(
                helperText: 'Final availability is verified when you submit.',
              ),
            ),
          ] else if (!isSpot) ...[
            const SizedBox(height: 20),
            const Text('Time', style: _labelStyle),
            const SizedBox(height: 8),
            _panel(ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.schedule_rounded, color: Color(0xFF38BDF8)),
              title: Text(_selectedTime.format(context),
                  style: const TextStyle(color: Colors.white)),
              onTap: _pickTime,
            )),
          ],
          const SizedBox(height: 20),
          const Text('Guests', style: _labelStyle),
          const SizedBox(height: 8),
          _panel(Row(children: [
            IconButton(
              onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_guests', style: const TextStyle(color: Colors.white)),
            IconButton(
              onPressed: _guests >= guestLimit
                  ? null
                  : () => setState(() => _guests++),
              icon: const Icon(Icons.add_circle_outline),
            ),
            Text('Maximum $guestLimit',
                style: const TextStyle(color: Color(0xFF94A3B8))),
          ])),
          const SizedBox(height: 20),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration:
                const InputDecoration(labelText: 'Special notes (optional)'),
          ),
          if (fee != null) ...[
            const SizedBox(height: 16),
            _panel(Text(
              'Verified reservation fee: ₱${fee.toStringAsFixed(2)} per guest\nEstimated total: ₱${(fee * _guests).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white),
            )),
          ] else ...[
            const SizedBox(height: 16),
            const Text('Fee information unavailable',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ],
          if (spot?.bookingInstructions?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            Text('Instructions: ${spot!.bookingInstructions}',
                style: const TextStyle(color: Color(0xFFCBD5E1))),
          ],
          if (spot?.cancellationPolicy?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text('Cancellation: ${spot!.cancellationPolicy}',
                style: const TextStyle(color: Color(0xFFCBD5E1))),
          ],
          const SizedBox(height: 28),
          if (!globalBookingEnabled)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Booking is temporarily disabled by the Tourism Office.',
                  style: TextStyle(color: Color(0xFFF59E0B))),
            ),
          FilledButton.icon(
            onPressed: _isSubmitting ||
                    !globalBookingEnabled ||
                    unavailable ||
                    msmeDateUnavailable ||
                    !serverAvailable ||
                    (isSpot && _selectedSpotUuid == null)
                ? null
                : () => _submit(spot, msme),
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.event_available_rounded),
            label: const Text('Submit Reservation'),
          ),
        ],
      ),
    );
  }

  Widget _panel(Widget child) => Material(
        color: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      );

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
  );
}
