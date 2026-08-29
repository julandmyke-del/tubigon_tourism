import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../authentication/auth_provider.dart';
import '../../../tourist_spots/models/tourist_spot.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../../../reservations/repositories/reservation_repository.dart';
import '../../../notifications/repositories/notification_repository.dart';

class TouristDashboardPage extends ConsumerWidget {
  const TouristDashboardPage({super.key});

  static const _quickActions = [
    (
      icon: Icons.directions_boat_rounded,
      label: 'Ferry',
      routeName: RouteNames.ferrySchedule,
      color: Color(0xFF38BDF8)
    ),
    (
      icon: Icons.eco_rounded,
      label: 'Eco Tips',
      routeName: RouteNames.ecoTips,
      color: Color(0xFF34D399)
    ),
    (
      icon: Icons.warning_amber_rounded,
      label: 'Emergency',
      routeName: RouteNames.emergencyContacts,
      color: Color(0xFFF87171)
    ),
    (
      icon: Icons.report_rounded,
      label: 'Report Issue',
      routeName: RouteNames.wasteReport,
      color: Color(0xFFF59E0B)
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final spotsAsync = ref.watch(touristSpotsListProvider);
    final bookingsAsync = ref.watch(userReservationsProvider);
    final unreadAsync = ref.watch(touristUnreadCountProvider);

    final userName = authState.isGuest
        ? 'Explorer'
        : (authState.name != null && authState.name!.isNotEmpty
            ? authState.name!.split(' ').first
            : 'Explorer');

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      body: CustomScrollView(
        slivers: [
          // ── Hero Header & App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            automaticallyImplyLeading: false,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                      Color(0xFF080F1A)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '👋 Good morning!',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12)),
                                ),
                                child:
                                    Stack(clipBehavior: Clip.none, children: [
                                  const Icon(Icons.notifications_outlined,
                                      color: Colors.white, size: 20),
                                  if ((unreadAsync.valueOrNull ?? 0) > 0)
                                    Positioned(
                                      right: -5,
                                      top: -5,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                            minWidth: 16, minHeight: 16),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        decoration: const BoxDecoration(
                                            color: Color(0xFFF87171),
                                            shape: BoxShape.circle),
                                        child: Text(
                                            '${unreadAsync.valueOrNull}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ]),
                              ),
                              onPressed: () => context.go('/notifications'),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context.go('/profile'),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFF59E0B), width: 2),
                                ),
                                child: const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Color(0xFF1E293B),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _SearchBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),

                // Quick actions section
                const _SectionHeader(
                  title: 'Quick Actions',
                  onSeeAll: null,
                ).animate().fadeIn(duration: 350.ms),
                const SizedBox(height: 14),
                const _QuickActionsRow(actions: _quickActions),
                const SizedBox(height: 28),

                // Featured spots section header
                _SectionHeader(
                  title: 'Featured Destinations',
                  onSeeAll: () => context.go('/explore'),
                ).animate().fadeIn(duration: 350.ms, delay: 100.ms),
                const SizedBox(height: 14),
              ]),
            ),
          ),

          // Featured spots carousel
          SliverToBoxAdapter(
            child: SizedBox(
              height: 252,
              child: spotsAsync.when(
                loading: () => ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, __) => Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                  ),
                ),
                error: (err, _) => Center(
                  child: Text('Failed to load spots',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6))),
                ),
                data: (allSpots) {
                  final featured = allSpots.where((s) => s.isFeatured).toList();
                  final spotsList = featured.isNotEmpty
                      ? featured
                      : allSpots.take(5).toList();

                  if (spotsList.isEmpty) {
                    return Center(
                      child: Text('No destinations available',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6))),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: spotsList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      return _SpotCard(spot: spotsList[i], index: i);
                    },
                  );
                },
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 28),

                // Upcoming Bookings preview
                _SectionHeader(
                  title: 'My Bookings',
                  onSeeAll: () => context.go('/reservations'),
                ).animate().fadeIn(duration: 350.ms, delay: 200.ms),
                const SizedBox(height: 14),
                _BookingPreviewCard(bookingsAsync: bookingsAsync),
                const SizedBox(height: 24),

                // Eco Banner
                _EcoBanner().animate().fadeIn(duration: 350.ms, delay: 300.ms),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/explore'),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 12),
            Text(
              'Search spots, activities, MSMEs…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'See All',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Quick Actions Row ────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.actions});

  final List<({IconData icon, String label, String routeName, Color color})>
      actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(actions.length, (i) {
        final action = actions[i];
        return Expanded(
          child: Semantics(
            button: true,
            label: 'Open ${action.label}',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.pushNamed(action.routeName),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: action.color.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: action.color.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(action.icon, color: action.color, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: (60 * i).ms).fadeIn(duration: 300.ms),
        );
      }),
    );
  }
}

// ─── Spot Card ────────────────────────────────────────────────────────────────
class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot, required this.index});

  final TouristSpot spot;
  final int index;

  @override
  Widget build(BuildContext context) {
    final category = spot.categoryName ?? 'Nature';
    Color catColor = const Color(0xFF38BDF8);

    if (category == 'Beach') catColor = const Color(0xFF38BDF8);
    if (category == 'Nature') catColor = const Color(0xFF34D399);
    if (category == 'Historical') catColor = const Color(0xFFF59E0B);
    if (category == 'Adventure') catColor = const Color(0xFFFB923C);
    if (category == 'Eco') catColor = const Color(0xFFA7F3D0);
    if (category == 'Cultural') catColor = const Color(0xFFC084FC);

    return GestureDetector(
      onTap: () => context.goNamed(
        RouteNames.touristSpotDetail,
        pathParameters: {'id': spot.id.toString()},
      ),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: catColor.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Image or color backdrop
              if (spot.images.isNotEmpty)
                Image.network(
                  spot.images.first,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _FallbackBackdrop(color: catColor),
                )
              else
                _FallbackBackdrop(color: catColor),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF080F1A).withValues(alpha: 0.6),
                      const Color(0xFF080F1A).withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),

              // Details Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: catColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        spot.canAcceptBookings
                            ? '$category · Reservations'
                            : spot.isBookable
                                ? '$category · Unavailable: ${spot.bookingUnavailableLabel}'
                                : category,
                        style: TextStyle(
                          color: catColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          spot.averageRating > 0
                              ? spot.averageRating.toStringAsFixed(1)
                              : 'New',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          spot.entranceFee == 0
                              ? 'Fee not listed'
                              : '₱${spot.entranceFee.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (spot.canAcceptBookings) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: FilledButton.icon(
                          onPressed: () => context.go(
                            '/reservations/create?spot=${Uri.encodeQueryComponent(spot.uuid)}',
                          ),
                          icon: const Icon(Icons.event_available_rounded,
                              size: 15),
                          label: const Text('Book',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate(delay: (80 * index).ms).fadeIn(duration: 350.ms),
    );
  }
}

class _FallbackBackdrop extends StatelessWidget {
  const _FallbackBackdrop({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.3), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.landscape_rounded,
            color: color.withValues(alpha: 0.4), size: 48),
      ),
    );
  }
}

// ─── Booking Preview Card ─────────────────────────────────────────────────────
class _BookingPreviewCard extends StatelessWidget {
  const _BookingPreviewCard({required this.bookingsAsync});

  final AsyncValue<List<dynamic>> bookingsAsync;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/reservations'),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: bookingsAsync.when(
          loading: () => Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Loading bookings…',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            ],
          ),
          error: (_, __) => const Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 12),
              Text('My Bookings',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          data: (bookings) {
            final upcoming = bookings
                .where((b) => b.status == 'confirmed' || b.status == 'pending')
                .toList();

            if (upcoming.isEmpty) {
              return Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: Color(0xFFF59E0B), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No upcoming bookings',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Explore spots and make a reservation!',
                          style:
                              TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF64748B)),
                ],
              );
            }

            final nextBooking = upcoming.first;
            return Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.confirmation_number_rounded,
                      color: Color(0xFF34D399), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextBooking.spotName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${nextBooking.reservationDate} · ${nextBooking.guests} Guests',
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
                    color: const Color(0xFF34D399).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    nextBooking.status.toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Eco Banner ───────────────────────────────────────────────────────────────
class _EcoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.ecoTips),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.eco_rounded, color: Colors.white, size: 36),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Travel Green 🌿',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Discover eco-friendly tips for your Tubigon visit',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
