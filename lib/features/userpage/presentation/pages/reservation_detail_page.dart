import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../reservations/repositories/reservation_repository.dart';
import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../itinerary/repositories/itinerary_repository.dart';
import '../../../map/providers/map_provider.dart';
import '../../../map/map_focus.dart';
import '../../../notifications/repositories/notification_repository.dart';
import '../../../connected_operations/presentation/reservation_conversation.dart';

class ReservationDetailPage extends ConsumerWidget {
  const ReservationDetailPage({super.key, required this.reservationUuid});

  final String reservationUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationAsync =
        ref.watch(reservationDetailProvider(reservationUuid));
    final mapMarkers = ref.watch(mapMarkersProvider).valueOrNull ?? const [];

    return reservationAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF080F1A),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: const Color(0xFF080F1A),
        body: Center(
            child: Text('Error loading booking: $err',
                style: const TextStyle(color: Colors.white))),
      ),
      data: (reservation) {
        final cleanRef = reservation.publicReference.isNotEmpty
            ? reservation.publicReference
            : reservation.id.length > 8
                ? reservation.id.substring(0, 8).toUpperCase()
                : reservation.id.toUpperCase();
        MapMarker? reservedPlace;
        for (final marker in mapMarkers) {
          final expectedType = switch (reservation.reservableType) {
            'spot' => MapMarkerCategory.touristSpot,
            'tourism_listing' => MapMarkerCategory.tourismListing,
            _ => MapMarkerCategory.msme,
          };
          if (marker.category == expectedType &&
              marker.sourceId == reservation.reservableId) {
            reservedPlace = marker;
            break;
          }
        }
        if (reservedPlace == null &&
            reservation.latitude != null &&
            reservation.longitude != null) {
          reservedPlace = MapMarker(
            id: '${reservation.reservableType}:${reservation.reservableId}',
            sourceId: reservation.reservableId,
            name: reservation.spotName,
            description: reservation.bookingInstructions ?? '',
            latitude: reservation.latitude!,
            longitude: reservation.longitude!,
            category: reservation.reservableType == 'spot'
                ? MapMarkerCategory.touristSpot
                : MapMarkerCategory.tourismListing,
          );
        }

        Color statusColor = const Color(0xFFF59E0B);
        if (reservation.status == 'confirmed') {
          statusColor = const Color(0xFF34D399);
        }
        if (reservation.status == 'cancelled') {
          statusColor = const Color(0xFFF87171);
        }
        if (reservation.status == 'completed') {
          statusColor = const Color(0xFF38BDF8);
        }

        return Scaffold(
          backgroundColor: const Color(0xFF080F1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Reservation Details',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Ticket Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1E293B)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: reservation.spotColor.withValues(alpha: 0.15),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: reservation.spotColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(reservation.spotIcon,
                                  color: reservation.spotColor, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reservation.spotName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Reference: $cleanRef',
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                reservation.status.toUpperCase(),
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Server-issued reservation reference
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SelectableText(
                                cleanRef,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .4),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Use this reference when contacting the destination',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      // Dashed Divider
                      Row(
                        children: List.generate(
                          30,
                          (i) => Expanded(
                            child: Container(
                              height: 1,
                              color: i % 2 == 0
                                  ? Colors.transparent
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),

                      // Booking Summary
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _SummaryRow(
                                label: 'Booking Date',
                                value: reservation.reservationDate),
                            const SizedBox(height: 12),
                            _SummaryRow(
                                label: 'Time Slot',
                                value: reservation.startTime ??
                                    'Flexible Entrance'),
                            const SizedBox(height: 12),
                            _SummaryRow(
                                label: 'Guests',
                                value: '${reservation.guests} Person(s)'),
                            const SizedBox(height: 12),
                            if (reservation.feeConfigured ||
                                reservation.reservableType != 'spot')
                              _SummaryRow(
                                  label: 'Total Cost',
                                  value:
                                      '₱${reservation.totalAmount.toStringAsFixed(2)}',
                                  isTotal: true)
                            else
                              const _SummaryRow(
                                label: 'Fee',
                                value: 'Fee information unavailable',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms),

                const SizedBox(height: 24),

                _StatusTimeline(status: reservation.status),

                if (reservation.items.isNotEmpty)
                  _ReservationInfo(
                    title: 'Booking Items',
                    value: reservation.items
                        .map((item) =>
                            '${item['offering_name_snapshot'] ?? 'Offering'} · ${item['quantity']} × ₱${item['unit_price_snapshot']} = ₱${item['subtotal']}')
                        .join('\n'),
                  ),

                if (reservation.statusHistory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReservationInfo(
                    title: 'Status History',
                    value: reservation.statusHistory
                        .map((entry) =>
                            '${entry.status.toUpperCase()}${entry.createdAt == null ? '' : ' · ${entry.createdAt}'}')
                        .join('\n'),
                  ),
                ],

                const SizedBox(height: 24),

                // Special Notes / Instructions Card
                if (reservation.notes != null && reservation.notes!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Special Notes',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(reservation.notes!,
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 13)),
                      ],
                    ),
                  ),

                if (reservation.bookingInstructions?.trim().isNotEmpty ?? false)
                  _ReservationInfo(
                    title: 'Destination Instructions',
                    value: reservation.bookingInstructions!,
                  ),

                if (reservation.cancellationPolicy?.trim().isNotEmpty ?? false)
                  _ReservationInfo(
                    title: 'Cancellation Policy',
                    value: reservation.cancellationPolicy!,
                  ),

                const SizedBox(height: 24),

                ReservationConversation(reservationId: reservation.id),

                const SizedBox(height: 24),

                if (reservedPlace != null)
                  OutlinedButton.icon(
                    onPressed: () => showAddToItinerarySheet(
                      context,
                      ref,
                      reservedPlace!,
                      reservationId: reservation.id,
                    ),
                    icon: const Icon(Icons.luggage_rounded),
                    label: const Text('Add Reservation to Itinerary'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),

                if (reservedPlace != null) const SizedBox(height: 12),

                if (reservedPlace != null)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push(mapFocusPathForMarker(reservedPlace!)),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('View on Map'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(
                          mapFocusPathForMarker(
                            reservedPlace!,
                            directions: true,
                          ),
                        ),
                        icon: const Icon(Icons.directions_rounded),
                        label: const Text('Directions'),
                      ),
                    ),
                  ]),

                if (reservedPlace != null) const SizedBox(height: 12),

                // Cancel Button
                if (reservation.status == 'pending' ||
                    reservation.status == 'confirmed')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF0F172A),
                          title: const Text('Cancel Reservation?',
                              style: TextStyle(color: Colors.white)),
                          content: const Text(
                              'Are you sure you want to cancel this booking?',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                          actions: [
                            TextButton(
                                onPressed: () => ctx.pop(false),
                                child: const Text('Keep Booking')),
                            ElevatedButton(
                              onPressed: () => ctx.pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF87171)),
                              child: const Text('Cancel Booking'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref
                            .read(reservationRepositoryProvider)
                            .cancelReservation(reservation.id);
                        ref.invalidate(reservationsListProvider);
                        ref.invalidate(
                            reservationDetailProvider(reservation.id));
                        ref.invalidate(touristNotificationsProvider);
                        ref.invalidate(touristUnreadCountProvider);
                        ref.invalidate(itinerariesProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Reservation cancelled.')),
                          );
                          context.pop();
                        }
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined,
                        color: Color(0xFFF87171)),
                    label: const Text('Cancel Booking',
                        style: TextStyle(
                            color: Color(0xFFF87171),
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Color(0xFFF87171)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReservationInfo extends StatelessWidget {
  const _ReservationInfo({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Color(0xFFCBD5E1))),
        ]),
      );
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cancelled = status == 'cancelled' || status == 'rejected';
    final activeIndex = switch (status) {
      'completed' => 2,
      'confirmed' || 'approved' => 1,
      _ => 0,
    };
    final steps = cancelled
        ? const [
            ('Pending', Icons.schedule_rounded),
            ('Cancelled', Icons.cancel_rounded)
          ]
        : const [
            ('Pending', Icons.schedule_rounded),
            ('Confirmed', Icons.check_circle_outline_rounded),
            ('Completed', Icons.verified_rounded),
          ];
    return Semantics(
      label: 'Reservation status: $status',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reservation Status',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final reached = cancelled ? true : index <= activeIndex;
            final color = cancelled && index == 1
                ? const Color(0xFFF87171)
                : reached
                    ? const Color(0xFF34D399)
                    : const Color(0xFF475569);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Icon(steps[index].$2, color: color, size: 22),
                if (index < steps.length - 1)
                  Container(
                      width: 2,
                      height: 24,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: color.withValues(alpha: .45)),
              ]),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(steps[index].$1,
                    style: TextStyle(
                        color: reached ? Colors.white : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
              ),
            ]);
          }),
        ]),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label, required this.value, this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? const Color(0xFFF59E0B) : Colors.white,
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
