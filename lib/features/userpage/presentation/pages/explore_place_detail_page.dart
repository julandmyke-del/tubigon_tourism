import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';
import '../../../favorites/repositories/favorites_repository.dart';
import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../map/place_category_style.dart';
import '../../../map/providers/map_provider.dart';
import '../../../map/providers/place_detail_provider.dart';
import '../../../map/map_focus.dart';

class ExplorePlaceDetailPage extends ConsumerStatefulWidget {
  const ExplorePlaceDetailPage({super.key, required this.placeId});

  final String placeId;

  @override
  ConsumerState<ExplorePlaceDetailPage> createState() =>
      _ExplorePlaceDetailPageState();
}

class _ExplorePlaceDetailPageState
    extends ConsumerState<ExplorePlaceDetailPage> {
  bool _favoriteBusy = false;

  @override
  Widget build(BuildContext context) {
    final place = ref.watch(placeDetailProvider(widget.placeId));
    final location = ref.watch(userLocationProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Place Details'),
      ),
      body: place.when(
        loading: () => const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: Color(0xFFF59E0B)),
            SizedBox(height: 12),
            Text('Loading place…', style: TextStyle(color: Color(0xFFCBD5E1))),
          ]),
        ),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: Color(0xFF64748B)),
            const SizedBox(height: 12),
            const Text('Unable to load this place.',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () =>
                  ref.invalidate(placeDetailProvider(widget.placeId)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
        data: (item) => LayoutBuilder(
          builder: (context, constraints) {
            final isFavorite = ref.watch(isFavoriteProvider(
              FavoriteKey(item.favoriteType, item.sourceId),
            ));
            final contentWidth =
                constraints.maxWidth > 850 ? 760.0 : double.infinity;
            final distance = location.hasLocation
                ? item.distanceTo(location.latitude!, location.longitude!)
                : null;
            final accent = placeCategoryColor(item.markerColor);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: accent.withValues(alpha: .55)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: .35),
                            blurRadius: 24,
                            offset: const Offset(0, 9)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: constraints.maxWidth > 650 ? 330 : 230,
                          child: item.images.isEmpty
                              ? DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      accent.withValues(alpha: .3),
                                      const Color(0xFF111827),
                                    ]),
                                  ),
                                  child: Icon(
                                      placeCategoryIcon(item.categoryIcon),
                                      color: accent,
                                      size: 76),
                                )
                              : CachedNetworkImage(
                                  imageUrl: item.images.first,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => ColoredBox(
                                    color: const Color(0xFF1E293B),
                                    child: Icon(
                                        placeCategoryIcon(item.categoryIcon),
                                        color: accent,
                                        size: 66),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _DetailBadge(
                                    icon: placeCategoryIcon(item.categoryIcon),
                                    label: item.categoryName ?? 'Place',
                                    color: accent),
                                _DetailBadge(
                                  icon: item.isVerified
                                      ? Icons.verified_rounded
                                      : Icons.schedule_rounded,
                                  label: item.isVerified
                                      ? 'LGU Verified'
                                      : 'Needs Verification',
                                  color: item.isVerified
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFFFBBF24),
                                ),
                              ]),
                              const SizedBox(height: 14),
                              Text(item.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                              Text(item.description,
                                  style: const TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 14,
                                      height: 1.55)),
                              const SizedBox(height: 16),
                              _InfoRow(
                                  icon: Icons.location_on_rounded,
                                  text: item.address ?? 'Tubigon, Bohol'),
                              if (item.rating != null)
                                _InfoRow(
                                    icon: Icons.star_rounded,
                                    text:
                                        '${item.rating!.toStringAsFixed(1)} rating${item.reviewCount == null ? '' : ' · ${item.reviewCount} reviews'}'),
                              if (distance != null)
                                _InfoRow(
                                    icon: Icons.near_me_rounded,
                                    text: distance < 1
                                        ? '${(distance * 1000).round()} m away'
                                        : '${distance.toStringAsFixed(1)} km away'),
                              if (item.operatingHours?.trim().isNotEmpty ??
                                  false)
                                _InfoRow(
                                    icon: Icons.schedule_rounded,
                                    text: item.operatingHours!.trim()),
                              if (item.contact?.trim().isNotEmpty ?? false)
                                _InfoRow(
                                    icon: Icons.call_rounded,
                                    text: item.contact!.trim()),
                              const SizedBox(height: 20),
                              Wrap(spacing: 10, runSpacing: 10, children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      foregroundColor: Colors.black),
                                  onPressed: () => _openMap(item),
                                  icon: const Icon(Icons.map_rounded),
                                  label: const Text('View on Map'),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF59E0B),
                                      foregroundColor: Colors.black),
                                  onPressed: () =>
                                      _openMap(item, directions: true),
                                  icon: const Icon(Icons.directions_rounded),
                                  label: const Text('Directions'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: item.isItineraryEligible
                                      ? () => showAddToItinerarySheet(
                                          context, ref, item)
                                      : null,
                                  icon: const Icon(Icons.luggage_rounded),
                                  label: const Text('Add to Itinerary'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _favoriteBusy
                                      ? null
                                      : () => _toggleFavorite(item),
                                  icon: Icon(_favoriteBusy
                                      ? Icons.hourglass_top_rounded
                                      : isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded),
                                  label: Text(isFavorite
                                      ? 'Remove Favorite'
                                      : 'Favorite'),
                                ),
                                if (item.hasCallableContact)
                                  OutlinedButton.icon(
                                    onPressed: () => _call(item.contact!),
                                    icon: const Icon(Icons.call_rounded),
                                    label: const Text('Call'),
                                  ),
                                if (item.hasFerrySchedules)
                                  OutlinedButton.icon(
                                    onPressed: () => context.push('/ferry'),
                                    icon: const Icon(
                                        Icons.directions_boat_rounded),
                                    label: const Text('Ferry Schedules'),
                                  ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openMap(MapMarker place, {bool directions = false}) {
    context.push(mapFocusPathForMarker(place, directions: directions));
  }

  Future<void> _toggleFavorite(MapMarker place) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      await requireSignedIn(
        context,
        ref,
        returnTo: '/explore/place/${widget.placeId}',
      );
      return;
    }
    if (auth.role != UserRole.tourist) {
      _message('Favorites are available to Tourist accounts.');
      return;
    }
    setState(() => _favoriteBusy = true);
    try {
      await ref
          .read(favoriteKeysProvider.notifier)
          .toggle(place.favoriteType, place.sourceId);
      if (mounted) _message('${place.name} favorite updated.');
    } catch (_) {
      if (mounted) _message('Unable to update favorites right now.');
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _call(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      if (mounted) _message('Calling is not available on this device.');
      return;
    }
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: clean),
          mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _message('Calling is not available on this device.');
      }
    } catch (_) {
      if (mounted) _message('Calling is not available on this device.');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0F172A),
    ));
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, color: const Color(0xFFF59E0B), size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
          ),
        ]),
      );
}
