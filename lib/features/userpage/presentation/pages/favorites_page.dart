import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';
import '../../../favorites/repositories/favorites_repository.dart';
import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../map/map_focus.dart';
import '../../../map/place_category_style.dart';
import '../../../map/providers/map_provider.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      return signedInRequiredPage(context, ref, title: 'Favorites');
    }

    final keys = ref.watch(favoriteKeysProvider);
    final places = ref.watch(mapMarkersProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('My Favorites'),
      ),
      body: keys.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
        error: (_, __) => _FavoritesMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to load Favorites',
          subtitle: 'Check your connection and try again.',
          action: () => ref.read(favoriteKeysProvider.notifier).reload(),
        ),
        data: (favoriteKeys) => places.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
          ),
          error: (_, __) => _FavoritesMessage(
            icon: Icons.place_outlined,
            title: 'Favorite places are unavailable',
            subtitle:
                'Previously saved public places will appear when available.',
            action: () => ref.invalidate(mapMarkersProvider),
          ),
          data: (allPlaces) {
            final favorites = allPlaces.where((place) {
              return favoriteKeys.contains(
                FavoriteKey(place.favoriteType, place.sourceId),
              );
            }).toList(growable: false);
            if (favorites.isEmpty) {
              return const _FavoritesMessage(
                icon: Icons.favorite_border_rounded,
                title: 'No favorites saved yet',
                subtitle: 'Tap a heart in Explore, Map, or place details.',
              );
            }
            return RefreshIndicator(
              color: const Color(0xFFF59E0B),
              onRefresh: () async {
                await ref.read(favoriteKeysProvider.notifier).reload();
                ref.invalidate(mapMarkersProvider);
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: favorites.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _FavoritePlaceCard(
                  place: favorites[index],
                  onOpen: () => _openPlace(context, favorites[index]),
                  onBook: favorites[index].category ==
                              MapMarkerCategory.touristSpot &&
                          favorites[index].canAcceptBookings
                      ? () => context.push(
                            '/reservations/create?spot=${Uri.encodeQueryComponent(favorites[index].sourceId)}',
                          )
                      : null,
                  onMap: () =>
                      context.push(mapFocusPathForMarker(favorites[index])),
                  onItinerary: favorites[index].isItineraryEligible
                      ? () => showAddToItinerarySheet(
                            context,
                            ref,
                            favorites[index],
                          )
                      : null,
                  onRemove: () =>
                      ref.read(favoriteKeysProvider.notifier).toggle(
                            favorites[index].favoriteType,
                            favorites[index].sourceId,
                          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static void _openPlace(BuildContext context, MapMarker place) {
    if (place.category == MapMarkerCategory.mapLocation &&
        place.mapLocationId != null) {
      context.push('/explore/place/${place.mapLocationId}');
      return;
    }
    final integerId = place.sourceIntegerId;
    if (place.category == MapMarkerCategory.touristSpot && integerId != null) {
      context.push('/explore/spot/$integerId');
    } else if (place.category == MapMarkerCategory.msme && integerId != null) {
      context.push('/explore/msme/$integerId');
    } else {
      context.push(mapFocusPathForMarker(place));
    }
  }
}

class _FavoritePlaceCard extends StatelessWidget {
  const _FavoritePlaceCard({
    required this.place,
    required this.onOpen,
    required this.onBook,
    required this.onMap,
    required this.onItinerary,
    required this.onRemove,
  });

  final MapMarker place;
  final VoidCallback onOpen;
  final VoidCallback? onBook;
  final VoidCallback onMap;
  final VoidCallback? onItinerary;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = placeCategoryColor(place.markerColor);
    return Card(
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: .35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(placeCategoryIcon(place.categoryIcon), color: accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(place.categoryName ?? 'Place',
                      style: TextStyle(color: accent, fontSize: 12)),
                  if (place.address?.trim().isNotEmpty ?? false)
                    Text(place.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11)),
                  if (place.category == MapMarkerCategory.touristSpot &&
                      place.isBookable &&
                      !place.bookingEnabled)
                    Text(
                      'Booking unavailable — ${place.bookingUnavailableLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            if (onBook != null)
              IconButton(
                tooltip: 'Book Destination',
                onPressed: onBook,
                icon: const Icon(Icons.event_available_rounded,
                    color: Color(0xFF34D399)),
              ),
            IconButton(
              tooltip: 'View on Map',
              onPressed: onMap,
              icon: const Icon(Icons.map_rounded, color: Color(0xFF38BDF8)),
            ),
            if (onItinerary != null)
              IconButton(
                tooltip: 'Add to Itinerary',
                onPressed: onItinerary,
                icon:
                    const Icon(Icons.luggage_rounded, color: Color(0xFFF59E0B)),
              ),
            IconButton(
              tooltip: 'Remove Favorite',
              onPressed: onRemove,
              icon:
                  const Icon(Icons.favorite_rounded, color: Color(0xFFF87171)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FavoritesMessage extends StatelessWidget {
  const _FavoritesMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 60, color: const Color(0xFF64748B)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8))),
            if (action != null) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ]),
        ),
      );
}
