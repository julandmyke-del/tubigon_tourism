import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/utils/auth_action_guard.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../tourist_spots/models/tourist_spot.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../../../tourist_spots/repositories/review_repository.dart';
import '../../../favorites/repositories/favorites_repository.dart';
import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../map/providers/map_provider.dart';

final spotFavoriteProvider =
    Provider.family<AsyncValue<bool>, String>((ref, spotUuid) {
  return ref.watch(favoriteKeysProvider).whenData(
        (keys) => keys.contains(FavoriteKey('spot', spotUuid)),
      );
});

class TouristSpotDetailPage extends ConsumerStatefulWidget {
  const TouristSpotDetailPage({super.key, required this.spotId});

  final int spotId;

  @override
  ConsumerState<TouristSpotDetailPage> createState() =>
      _TouristSpotDetailPageState();
}

class _TouristSpotDetailPageState extends ConsumerState<TouristSpotDetailPage> {
  final _commentCtrl = TextEditingController();
  int _selectedRating = 5;
  bool _favoriteLoading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _showAddReviewDialog(TouristSpot spot) {
    _selectedRating = 5;
    _commentCtrl.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Write a Review',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'How was your experience with ${spot.name}?',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    RatingInput(
                      initialRating: _selectedRating,
                      onChanged: (val) {
                        setDialogState(() {
                          _selectedRating = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _commentCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Share details of your experience...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final comment = _commentCtrl.text.trim();
                    if (comment.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a comment.')),
                      );
                      return;
                    }
                    if (comment.length < 3 || comment.length > 1000) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Review must be between 3 and 1000 characters.')),
                      );
                      return;
                    }

                    try {
                      final synced =
                          await ref.read(reviewRepositoryProvider).addReview(
                                reviewableType: 'spot',
                                reviewableId: spot.uuid,
                                rating: _selectedRating.toDouble(),
                                content: comment,
                              );

                      ref.invalidate(spotReviewsProvider(('spot', spot.uuid)));

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF10B981),
                          content: Text(synced
                              ? 'Review submitted successfully!'
                              : 'Review saved offline and pending synchronization.'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Submission failed: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spotsAsync = ref.watch(touristSpotsListProvider);

    return spotsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF080F1A),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: const Color(0xFF080F1A),
        body: Center(
            child: Text('Error loading spot details: $err',
                style: const TextStyle(color: Colors.white))),
      ),
      data: (spots) {
        final spot = spots.firstWhere(
          (s) => s.id == widget.spotId,
          orElse: () => TouristSpot(
            id: 0,
            uuid: '',
            name: 'Not Found',
            slug: 'not-found',
            description: 'This tourist spot does not exist.',
            latitude: 0,
            longitude: 0,
            address: 'Unknown',
            entranceFee: 0,
            openingHours: '',
            ecoTips: [],
            images: [],
            averageRating: 0,
            reviewCount: 0,
            isFeatured: false,
            isActive: false,
          ),
        );

        if (spot.id == 0) {
          return const Scaffold(
            backgroundColor: Color(0xFF080F1A),
            body: Center(
                child: Text('Spot not found.',
                    style: TextStyle(color: Colors.white))),
          );
        }

        final category = spot.categoryName ?? 'Nature';
        Color spotColor = const Color(0xFF38BDF8);

        if (category == 'Beach') spotColor = const Color(0xFF38BDF8);
        if (category == 'Nature') spotColor = const Color(0xFF34D399);
        if (category == 'Historical') spotColor = const Color(0xFFF59E0B);
        if (category == 'Adventure') spotColor = const Color(0xFFFB923C);
        if (category == 'Eco') spotColor = const Color(0xFFA7F3D0);
        if (category == 'Cultural') spotColor = const Color(0xFFC084FC);

        final isFavAsync = ref.watch(spotFavoriteProvider(spot.uuid));
        final reviewsAsync =
            ref.watch(spotReviewsProvider(('spot', spot.uuid)));

        return Scaffold(
          backgroundColor: const Color(0xFF080F1A),
          body: CustomScrollView(
            slivers: [
              // ── App Bar Header with Image Gallery ─────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: const Color(0xFF0F172A),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  isFavAsync.when(
                    data: (isFav) => IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? const Color(0xFFF87171) : Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () async {
                        if (_favoriteLoading) return;
                        if (!await requireSignedIn(context, ref) || !mounted) {
                          return;
                        }
                        setState(() => _favoriteLoading = true);
                        try {
                          await ref
                              .read(favoriteKeysProvider.notifier)
                              .toggle('spot', spot.uuid);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _favoriteLoading = false);
                        }
                      },
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (spot.images.isNotEmpty)
                        Image.network(
                          spot.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _SpotHeaderBackdrop(spotColor: spotColor),
                        )
                      else
                        _SpotHeaderBackdrop(spotColor: spotColor),

                      // Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF080F1A).withValues(alpha: 0.5),
                              const Color(0xFF080F1A),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Main Body Content ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Tag + Rating
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: spotColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: spotColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: spotColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            spot.averageRating > 0
                                ? '${spot.averageRating.toStringAsFixed(1)} (${spot.reviewCount} reviews)'
                                : '4.8 (284 reviews)',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ).animate().fadeIn(duration: 350.ms),

                      const SizedBox(height: 10),

                      Text(
                        spot.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(duration: 350.ms, delay: 100.ms),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              spot.address.isNotEmpty
                                  ? spot.address
                                  : 'Tubigon, Bohol',
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 350.ms, delay: 150.ms),

                      const SizedBox(height: 20),

                      // Key Metadata Chips
                      Row(
                        children: [
                          Expanded(
                            child: _MetaStatCard(
                              icon: Icons.confirmation_number_outlined,
                              label: 'Entry Fee',
                              value: spot.entranceFee == 0
                                  ? 'Not listed'
                                  : '₱${spot.entranceFee.toStringAsFixed(0)}',
                              color: const Color(0xFF34D399),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetaStatCard(
                              icon: Icons.access_time_rounded,
                              label: 'Hours',
                              value: spot.openingHours.isNotEmpty
                                  ? spot.openingHours
                                  : 'Not listed',
                              color: const Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 350.ms, delay: 200.ms),

                      const SizedBox(height: 24),

                      // Description
                      const Text(
                        'About Destination',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        spot.description,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (spot.canAcceptBookings) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: .35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Reservations Available',
                                  style: TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(
                                spot.bookingMode == 'date_time_slot'
                                    ? 'Choose a date and a configured time slot.'
                                    : 'Choose an available reservation date.',
                                style:
                                    const TextStyle(color: Color(0xFFCBD5E1)),
                              ),
                              if (spot.maxGuestsPerReservation != null)
                                Text(
                                    'Maximum ${spot.maxGuestsPerReservation} guests per request',
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8))),
                              Text(
                                spot.feeConfigured &&
                                        spot.reservationFee != null
                                    ? 'Verified fee: ₱${spot.reservationFee!.toStringAsFixed(2)} per guest'
                                    : 'Fee information unavailable',
                                style:
                                    const TextStyle(color: Color(0xFF94A3B8)),
                              ),
                              if (spot.bookingInstructions?.trim().isNotEmpty ??
                                  false)
                                Text(
                                    'Instructions: ${spot.bookingInstructions}',
                                    style: const TextStyle(
                                        color: Color(0xFFCBD5E1))),
                              if (spot.cancellationPolicy?.trim().isNotEmpty ??
                                  false)
                                Text('Cancellation: ${spot.cancellationPolicy}',
                                    style: const TextStyle(
                                        color: Color(0xFFCBD5E1))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else if (spot.isBookable) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1720),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF87171)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Booking Temporarily Unavailable',
                                  style: TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text('Reason: ${spot.bookingUnavailableLabel}',
                                  style: const TextStyle(
                                      color: Color(0xFFFECACA),
                                      fontWeight: FontWeight.w700)),
                              if (spot.bookingUnavailableReason
                                      ?.trim()
                                      .isNotEmpty ==
                                  true)
                                Text(spot.bookingUnavailableReason!,
                                    style: const TextStyle(
                                        color: Color(0xFFFECACA))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Eco Tips Section
                      if (spot.ecoTips.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.eco_rounded,
                                      color: Color(0xFF34D399), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Eco Guidelines',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...spot.ecoTips.map((tip) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ',
                                            style: TextStyle(
                                                color: Color(0xFF34D399),
                                                fontSize: 14)),
                                        Expanded(
                                          child: Text(tip,
                                              style: const TextStyle(
                                                  color: Color(0xFFCBD5E1),
                                                  fontSize: 13)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Reviews Header & Write Review
                      Row(
                        children: [
                          const Text(
                            'Reviews & Ratings',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              if (await requireSignedIn(context, ref) &&
                                  context.mounted) {
                                _showAddReviewDialog(spot);
                              }
                            },
                            child: const Text(
                              'Write a Review',
                              style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      reviewsAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFF59E0B))),
                        error: (err, _) => Text('Error loading reviews: $err',
                            style: const TextStyle(color: Colors.white54)),
                        data: (reviewsList) {
                          if (reviewsList.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                    'No reviews yet. Be the first to share your experience!',
                                    style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 13)),
                              ),
                            );
                          }
                          return Column(
                            children: reviewsList
                                .map((r) => _ReviewTile(review: r))
                                .toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showAddToItinerarySheet(
                      context,
                      ref,
                      MapMarker(
                        id: 'tourist-spot:${spot.uuid}',
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
                        rating: spot.averageRating,
                        reviewCount: spot.reviewCount,
                        operatingHours: spot.openingHours,
                        isVerified: spot.isActive,
                        isBookable: spot.isBookable,
                        bookingEnabled: spot.bookingEnabled,
                        bookingUnavailableReasonCode:
                            spot.bookingUnavailableReasonCode,
                        bookingUnavailableReason: spot.bookingUnavailableReason,
                      ),
                    ),
                    icon: const Icon(Icons.luggage_rounded),
                    label: const Text('Add to Trip'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (spot.canAcceptBookings) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (await requireSignedIn(
                              context,
                              ref,
                              returnTo:
                                  '/reservations/create?spot=${Uri.encodeComponent(spot.uuid)}',
                            ) &&
                            context.mounted) {
                          context.goNamed(
                            RouteNames.createReservation,
                            queryParameters: {'spot': spot.uuid},
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Book'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpotHeaderBackdrop extends StatelessWidget {
  const _SpotHeaderBackdrop({required this.spotColor});
  final Color spotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Icon(Icons.landscape_rounded,
            color: spotColor.withValues(alpha: 0.3), size: 80),
      ),
    );
  }
}

class _MetaStatCard extends StatelessWidget {
  const _MetaStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                child: Text(
                  review.authorName.isNotEmpty
                      ? review.authorName[0].toUpperCase()
                      : 'T',
                  style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.authorName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('Verified Tourist',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11)),
                ],
              ),
              const Spacer(),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.content,
            style: const TextStyle(
                color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
