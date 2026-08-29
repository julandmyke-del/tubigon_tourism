import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';
import '../../../reservations/models/reservation.dart';
import '../../../reservations/repositories/reservation_repository.dart';

class ReservationsPage extends ConsumerStatefulWidget {
  const ReservationsPage({super.key});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF080F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('My Bookings'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 60, color: Color(0xFF64748B)),
                const SizedBox(height: 16),
                const Text('Sign in to manage bookings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                    'Guest browsing remains available in Explore and Map.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => requireSignedIn(context, ref),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final reservationsAsync = ref.watch(reservationsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'My Bookings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF59E0B),
          labelColor: const Color(0xFFF59E0B),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'All Bookings'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.black,
        onPressed: () => context.goNamed(RouteNames.createReservation),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Booking',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: reservationsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (err, _) => Center(
            child: Text('Error loading bookings: $err',
                style: const TextStyle(color: Colors.white70))),
        data: (allReservations) {
          List<Reservation> filter(String status) {
            if (status == 'upcoming') {
              return allReservations
                  .where(
                      (r) => r.status == 'confirmed' || r.status == 'pending')
                  .toList();
            } else if (status == 'completed') {
              return allReservations
                  .where((r) => r.status == 'completed')
                  .toList();
            }
            return allReservations;
          }

          return RefreshIndicator(
            color: const Color(0xFFF59E0B),
            backgroundColor: const Color(0xFF0F172A),
            onRefresh: () => ref.refresh(reservationsListProvider.future),
            child: TabBarView(
              controller: _tabController,
              children: [
                _ReservationList(reservations: filter('all')),
                _ReservationList(reservations: filter('upcoming')),
                _ReservationList(reservations: filter('completed')),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReservationList extends StatelessWidget {
  const _ReservationList({required this.reservations});

  final List<Reservation> reservations;

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 64, color: Color(0xFF475569)),
            SizedBox(height: 16),
            Text('No bookings found',
                style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Explore destinations and make a reservation!',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: reservations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        return _ReservationCard(reservation: reservations[i], index: i);
      },
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.index});

  final Reservation reservation;
  final int index;

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF34D399);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFF87171);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _statusLabel(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final cleanUuid = reservation.publicReference.isNotEmpty
        ? reservation.publicReference
        : reservation.id.length > 8
            ? reservation.id.substring(0, 8)
            : reservation.id;
    final hasDisplayedFee =
        reservation.reservableType != 'spot' || reservation.feeConfigured;

    return GestureDetector(
      onTap: () => context.goNamed(
        RouteNames.reservationDetail,
        pathParameters: {'uuid': reservation.id},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: reservation.spotColor.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: reservation.spotColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(reservation.spotIcon,
                        color: reservation.spotColor, size: 24),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ref: $cleanUuid',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(reservation.status)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _statusColor(reservation.status)
                              .withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _statusLabel(reservation.status),
                      style: TextStyle(
                        color: _statusColor(reservation.status),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DATE & GUESTS',
                          style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '${reservation.reservationDate} · ${reservation.guests} Guests',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(hasDisplayedFee ? 'TOTAL AMOUNT' : 'FEE',
                          style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        hasDisplayedFee
                            ? '₱${reservation.totalAmount.toStringAsFixed(0)}'
                            : 'Not listed',
                        style: TextStyle(
                            color: reservation.spotColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate(delay: (60 * index).ms).fadeIn(duration: 350.ms),
    );
  }
}
