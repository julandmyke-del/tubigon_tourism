import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';
import '../../../favorites/repositories/favorites_repository.dart';
import '../../../map/place_category_style.dart';
import '../../../map/providers/map_provider.dart';
import '../../../map/map_focus.dart';
import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';

enum _ExploreSort { recommended, rating, nearest, popular, recent }

class TouristSpotsPage extends ConsumerStatefulWidget {
  const TouristSpotsPage({super.key});

  @override
  ConsumerState<TouristSpotsPage> createState() => _TouristSpotsPageState();
}

class _TouristSpotsPageState extends ConsumerState<TouristSpotsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  String _category = 'all';
  _ExploreSort _sort = _ExploreSort.recommended;
  bool _verifiedOnly = false;
  bool _featuredOnly = false;
  String? _favoriteBusyId;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final places = ref.watch(mapMarkersProvider);
    final destinations = ref.watch(touristSpotsListProvider);
    final location = ref.watch(userLocationProvider);
    final favoriteKeys =
        ref.watch(favoriteKeysProvider).valueOrNull ?? const {};

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explore Tubigon',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            Text('Useful places, local favorites, and hidden gems',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'My Itineraries',
              onPressed: () => context.push('/itineraries'),
              icon:
                  const Icon(Icons.luggage_rounded, color: Color(0xFFF59E0B))),
        ],
      ),
      body: places.when(
        loading: _loading,
        error: (_, __) => _ExploreError(
          onRetry: () {
            ref.invalidate(mapMarkersProvider);
            ref.invalidate(mapPlaceCategoriesProvider);
          },
        ),
        data: (allPlaces) {
          final combined = List<MapMarker>.of(allPlaces);
          final mappedSpotIds = combined
              .where((item) => item.category == MapMarkerCategory.touristSpot)
              .map((item) => item.sourceId)
              .toSet();
          for (final spot in destinations.valueOrNull ?? const []) {
            if (!mappedSpotIds.add(spot.uuid)) continue;
            combined.add(MapMarker(
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
              rating: spot.averageRating > 0 ? spot.averageRating : null,
              reviewCount: spot.reviewCount,
              operatingHours: spot.openingHours,
              isVerified: spot.isPublished,
              isFeatured: spot.isFeatured,
              isBookable: spot.isBookable,
              bookingEnabled: spot.bookingEnabled,
              bookingUnavailableReasonCode: spot.bookingUnavailableReasonCode,
              bookingUnavailableReason: spot.bookingUnavailableReason,
              categorySlug: 'tourist-spots',
              categoryKeys: const ['tourist-spots'],
              categoryIcon: 'landscape',
            ));
          }
          final publicPlaces = combined
              .where((place) => place.category != MapMarkerCategory.wasteReport)
              .toList(growable: false);
          final categories = _categories(publicPlaces);
          final filtered = _filtered(publicPlaces, location);
          return RefreshIndicator(
            color: const Color(0xFFF59E0B),
            backgroundColor: const Color(0xFF0F172A),
            onRefresh: () async {
              ref.invalidate(mapPlaceCategoriesProvider);
              ref.invalidate(mapMarkersProvider);
              ref.invalidate(touristSpotsListProvider);
              final refreshed = await ref.read(mapMarkersProvider.future);
              if (refreshed.isEmpty) return;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _hero(publicPlaces.length)),
                SliverToBoxAdapter(child: _searchAndFilters(location)),
                SliverToBoxAdapter(child: _categoryBar(categories)),
                if (_showDiscoverySections) ...[
                  if (_featured(publicPlaces).isNotEmpty)
                    _rail(
                        'Featured Places in Tubigon',
                        'Curated highlights around Tubigon',
                        _featured(publicPlaces),
                        location),
                  if (location.hasLocation &&
                      _nearby(publicPlaces, location).isNotEmpty)
                    _rail(
                        'Nearby places',
                        'Closest places to your current location',
                        _nearby(publicPlaces, location),
                        location),
                  if (_popular(publicPlaces).isNotEmpty)
                    _rail(
                        'Popular places',
                        'Highly rated and frequently discovered',
                        _popular(publicPlaces),
                        location),
                  if (_verified(publicPlaces).isNotEmpty)
                    _rail(
                        'Verified places',
                        'Locations confirmed by Tubigon LGU',
                        _verified(publicPlaces),
                        location),
                  if (_recent(publicPlaces).isNotEmpty)
                    _rail(
                        'Recently added',
                        'Fresh additions to the discovery map',
                        _recent(publicPlaces),
                        location),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: Row(children: [
                      const Expanded(
                        child: Text('Explore all places',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ),
                      Text('${filtered.length} places',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 12)),
                    ]),
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ExploreEmpty(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final columns = width >= 1100
                            ? 4
                            : width >= 720
                                ? 3
                                : width >= 500
                                    ? 2
                                    : 1;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: columns == 1 ? 432 : 450,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _ExplorePlaceCard(
                              place: filtered[index],
                              distanceKm: _distance(filtered[index], location),
                              favoriteBusy:
                                  _favoriteBusyId == filtered[index].id,
                              isFavorite: favoriteKeys.contains(FavoriteKey(
                                filtered[index].favoriteType,
                                filtered[index].sourceId,
                              )),
                              onDetails: () => _openDetails(filtered[index]),
                              onBook: filtered[index].category ==
                                          MapMarkerCategory.touristSpot &&
                                      filtered[index].canAcceptBookings
                                  ? () => context.push(
                                        '/reservations/create?spot=${Uri.encodeQueryComponent(filtered[index].sourceId)}',
                                      )
                                  : null,
                              onMap: filtered[index].hasCoordinates
                                  ? () => _openMap(filtered[index])
                                  : null,
                              onDirections: filtered[index].hasCoordinates
                                  ? () => _openMap(filtered[index],
                                      directions: true)
                                  : null,
                              onFavorite: () =>
                                  _toggleFavorite(filtered[index]),
                              onItinerary: () => showAddToItinerarySheet(
                                  context, ref, filtered[index]),
                            ),
                            childCount: filtered.length,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _showDiscoverySections =>
      _query.isEmpty && _category == 'all' && !_verifiedOnly && !_featuredOnly;

  Widget _hero(int count) => Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF172554), Color(0xFF0F172A), Color(0xFF431407)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .42)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: .12),
                blurRadius: 28,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DISCOVER TUBIGON',
                    style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                const Text('Find your next stop',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                    '$count published places share one live Explore + Smart Map feed.',
                    style: const TextStyle(
                        color: Color(0xFFCBD5E1), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .15)),
            ),
            child: const Icon(Icons.travel_explore_rounded,
                color: Color(0xFFF59E0B), size: 32),
          ),
        ]),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: .08);

  Widget _searchAndFilters(UserLocationState location) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: _glass(radius: 18),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce =
                      Timer(const Duration(milliseconds: 280), () {
                    if (mounted) setState(() => _query = value.trim());
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search mall, food, bank, tourist spot…',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFFF59E0B)),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchDebounce?.cancel();
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF94A3B8))),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SquareButton(
            tooltip: 'Sort and filter',
            icon: Icons.tune_rounded,
            active: _verifiedOnly ||
                _featuredOnly ||
                _sort != _ExploreSort.recommended,
            onPressed: _showFilterSheet,
          ),
          const SizedBox(width: 8),
          _SquareButton(
            tooltip:
                location.hasLocation ? 'Location available' : 'Find nearby',
            icon: location.isLoading
                ? Icons.hourglass_top_rounded
                : Icons.my_location_rounded,
            active: location.hasLocation,
            onPressed: location.isLoading ? null : _locate,
          ),
        ]),
      );

  Widget _categoryBar(List<MapPlaceCategory> categories) => SizedBox(
        height: 44,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = index == 0 ? null : categories[index - 1];
            final slug = category?.slug ?? 'all';
            final selected = slug == _category;
            return FilterChip(
              selected: selected,
              showCheckmark: false,
              avatar: category == null
                  ? const Icon(Icons.apps_rounded, size: 16)
                  : Icon(placeCategoryIcon(category.icon), size: 16),
              label: Text(category?.name ?? 'All'),
              onSelected: (_) => setState(() => _category = slug),
              backgroundColor: const Color(0xFF0F172A),
              selectedColor: const Color(0xFFF59E0B),
              side: BorderSide(
                  color: selected
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF334155)),
              labelStyle: TextStyle(
                  color: selected ? Colors.black : const Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            );
          },
        ),
      );

  SliverToBoxAdapter _rail(String title, String subtitle,
      List<MapMarker> places, UserLocationState location) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(subtitle,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 172,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: places.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final place = places[index];
                return _DiscoveryTile(
                  place: place,
                  distanceKm: _distance(place, location),
                  onTap: () => _openDetails(place),
                  onMap: place.hasCoordinates ? () => _openMap(place) : null,
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  List<MapPlaceCategory> _categories(List<MapMarker> places) {
    final configured = ref.watch(mapPlaceCategoriesProvider).valueOrNull ??
        const <MapPlaceCategory>[];
    if (configured.isNotEmpty) return configured;
    final result = <String, MapPlaceCategory>{};
    for (final place in places) {
      result.putIfAbsent(
        place.categorySlug,
        () => MapPlaceCategory(
          id: place.categorySlug,
          name: place.categoryName ?? 'Places',
          slug: place.categorySlug,
          icon: place.categoryIcon,
          markerColor: place.markerColor,
          sortOrder: place.categorySortOrder,
        ),
      );
    }
    final list = result.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<MapMarker> _filtered(
      List<MapMarker> places, UserLocationState location) {
    final query = _query.toLowerCase();
    final result = places.where((place) {
      final categoryMatches =
          _category == 'all' || place.categoryKeys.contains(_category);
      final searchable =
          '${place.name} ${place.aliases.join(' ')} ${place.description} ${place.address ?? ''} ${place.categoryName ?? ''} ${place.categoryKeys.join(' ')}'
              .toLowerCase();
      return categoryMatches &&
          searchable.contains(query) &&
          (!_verifiedOnly || place.isVerified) &&
          (!_featuredOnly || place.isFeatured);
    }).toList();
    result.sort((a, b) => switch (_sort) {
          _ExploreSort.rating => (b.rating ?? 0).compareTo(a.rating ?? 0),
          _ExploreSort.nearest when location.hasLocation => a
              .distanceTo(location.latitude!, location.longitude!)
              .compareTo(b.distanceTo(location.latitude!, location.longitude!)),
          _ExploreSort.popular => _popularity(b).compareTo(_popularity(a)),
          _ExploreSort.recent => (b.createdAt ?? DateTime(1970))
              .compareTo(a.createdAt ?? DateTime(1970)),
          _ => _recommendedScore(b).compareTo(_recommendedScore(a)),
        });
    return result;
  }

  List<MapMarker> _featured(List<MapMarker> places) =>
      places.where((place) => place.isFeatured).take(8).toList();

  List<MapMarker> _nearby(List<MapMarker> places, UserLocationState location) {
    final sorted = List<MapMarker>.of(places)
      ..sort((a, b) => a
          .distanceTo(location.latitude!, location.longitude!)
          .compareTo(b.distanceTo(location.latitude!, location.longitude!)));
    return sorted.take(8).toList();
  }

  List<MapMarker> _popular(List<MapMarker> places) {
    final sorted = List<MapMarker>.of(places)
      ..sort((a, b) => _popularity(b).compareTo(_popularity(a)));
    return sorted.where((place) => _popularity(place) > 0).take(8).toList();
  }

  List<MapMarker> _verified(List<MapMarker> places) =>
      places.where((place) => place.isVerified).take(8).toList();

  List<MapMarker> _recent(List<MapMarker> places) {
    final sorted = List<MapMarker>.of(places)
      ..sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));
    return sorted.take(8).toList();
  }

  double _popularity(MapMarker place) =>
      (place.rating ?? 0) * 20 + (place.reviewCount ?? 0) + place.viewCount;

  double _recommendedScore(MapMarker place) =>
      (place.isFeatured ? 1000 : 0) +
      (place.isVerified ? 100 : 0) +
      _popularity(place);

  double? _distance(MapMarker place, UserLocationState location) =>
      location.hasLocation && place.hasCoordinates
          ? place.distanceTo(location.latitude!, location.longitude!)
          : null;

  Future<void> _locate() async {
    final found = await ref.read(userLocationProvider.notifier).locate();
    if (!mounted) return;
    if (!found) {
      _message('Nearby is optional. You can keep exploring without GPS.');
    } else {
      setState(() => _sort = _ExploreSort.nearest);
    }
  }

  void _openDetails(MapMarker place) {
    if (place.category == MapMarkerCategory.mapLocation &&
        place.mapLocationId != null) {
      context.push('/explore/place/${place.mapLocationId}');
      return;
    }
    final id = place.sourceIntegerId;
    if (place.category == MapMarkerCategory.touristSpot && id != null) {
      context.push('/explore/spot/$id');
    } else if (place.category == MapMarkerCategory.msme && id != null) {
      context.push('/explore/msme/$id');
    } else {
      _openMap(place);
    }
  }

  void _openMap(MapMarker place, {bool directions = false}) {
    context.push(mapFocusPathForMarker(place, directions: directions));
  }

  Future<void> _toggleFavorite(MapMarker place) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      await requireSignedIn(context, ref, returnTo: '/explore');
      return;
    }
    if (auth.role != UserRole.tourist) {
      _message('Favorites are available to Tourist accounts.');
      return;
    }
    if (!place.isFavoritable) {
      _message('Favorites are not available for this location type.');
      return;
    }
    setState(() => _favoriteBusyId = place.id);
    try {
      await ref
          .read(favoriteKeysProvider.notifier)
          .toggle(place.favoriteType, place.sourceId);
      if (mounted) _message('${place.name} favorite updated.');
    } catch (_) {
      if (mounted) _message('Unable to update favorites right now.');
    } finally {
      if (mounted) setState(() => _favoriteBusyId = null);
    }
  }

  Future<void> _showFilterSheet() async {
    var sort = _sort;
    var verified = _verifiedOnly;
    var featured = _featuredOnly;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Row(children: [
                Icon(Icons.tune_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text('Sort and filter',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<_ExploreSort>(
                initialValue: sort,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sort places',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: _ExploreSort.recommended,
                      child: Text('Recommended')),
                  DropdownMenuItem(
                      value: _ExploreSort.rating, child: Text('Highest rated')),
                  DropdownMenuItem(
                      value: _ExploreSort.nearest, child: Text('Nearest')),
                  DropdownMenuItem(
                      value: _ExploreSort.popular, child: Text('Most popular')),
                  DropdownMenuItem(
                      value: _ExploreSort.recent,
                      child: Text('Recently added')),
                ],
                onChanged: (value) {
                  if (value != null) setSheetState(() => sort = value);
                },
              ),
              SwitchListTile(
                value: verified,
                onChanged: (value) => setSheetState(() => verified = value),
                activeThumbColor: const Color(0xFFF59E0B),
                title: const Text('LGU verified only',
                    style: TextStyle(color: Colors.white)),
              ),
              SwitchListTile(
                value: featured,
                onChanged: (value) => setSheetState(() => featured = value),
                activeThumbColor: const Color(0xFFF59E0B),
                title: const Text('Featured only',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    setState(() {
                      _sort = sort;
                      _verifiedOnly = verified;
                      _featuredOnly = featured;
                    });
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Apply filters'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _loading() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 18),
          const Center(
              child: Text('Loading places…',
                  style: TextStyle(color: Color(0xFFCBD5E1)))),
          const SizedBox(height: 20),
          for (var i = 0; i < 4; i++)
            Container(
              height: 190,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: _glass(radius: 22),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 1300.ms),
        ],
      );

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0F172A),
    ));
  }
}

class _ExplorePlaceCard extends StatelessWidget {
  const _ExplorePlaceCard({
    required this.place,
    required this.distanceKm,
    required this.favoriteBusy,
    required this.isFavorite,
    required this.onDetails,
    required this.onBook,
    required this.onMap,
    required this.onDirections,
    required this.onFavorite,
    required this.onItinerary,
  });

  final MapMarker place;
  final double? distanceKm;
  final bool favoriteBusy;
  final bool isFavorite;
  final VoidCallback onDetails;
  final VoidCallback? onBook;
  final VoidCallback? onMap;
  final VoidCallback? onDirections;
  final VoidCallback onFavorite;
  final VoidCallback onItinerary;

  @override
  Widget build(BuildContext context) {
    final accent = placeCategoryColor(place.markerColor);
    return Container(
      decoration: _glass(radius: 22, accent: accent),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          SizedBox(
            height: 145,
            width: double.infinity,
            child: place.images.isEmpty
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: .32),
                          const Color(0xFF111827)
                        ],
                      ),
                    ),
                    child: Icon(placeCategoryIcon(place.categoryIcon),
                        color: accent, size: 52),
                  )
                : CachedNetworkImage(
                    imageUrl: place.images.first,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => ColoredBox(
                      color: const Color(0xFF1E293B),
                      child: Icon(placeCategoryIcon(place.categoryIcon),
                          color: accent, size: 46),
                    ),
                  ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: _Badge(
              icon: placeCategoryIcon(place.categoryIcon),
              label: (place.categoryName ?? 'Place').toUpperCase(),
              color: accent,
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: _Badge(
              icon: place.isVerified
                  ? Icons.verified_rounded
                  : Icons.schedule_rounded,
              label: place.isVerified ? 'LGU VERIFIED' : 'NEEDS VERIFICATION',
              color: place.isVerified
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFFFBBF24),
            ),
          ),
        ]),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(place.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12, height: 1.35)),
              const SizedBox(height: 7),
              Row(children: [
                const Icon(Icons.location_on_rounded,
                    size: 15, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(place.address ?? 'Tubigon, Bohol',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFCBD5E1), fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 7),
              Wrap(spacing: 12, runSpacing: 4, children: [
                if (place.rating != null)
                  Text('★ ${place.rating!.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                if (distanceKm != null)
                  Text(_distanceLabel(distanceKm!),
                      style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                if (place.isFeatured)
                  const Text('FEATURED',
                      style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                if (place.canAcceptBookings)
                  const Text('RESERVATIONS AVAILABLE',
                      style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                if (place.isBookable && !place.bookingEnabled)
                  Text(
                      'UNAVAILABLE — ${place.bookingUnavailableLabel.toUpperCase()}',
                      style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
              ]),
              const Spacer(),
              if (onBook != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: FilledButton.icon(
                    onPressed: onBook,
                    icon: const Icon(Icons.event_available_rounded, size: 17),
                    label: const Text('Book this destination'),
                  ),
                ),
                const SizedBox(height: 7),
              ],
              Row(children: [
                SizedBox(
                  width: 105,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: onDetails,
                    child: const Text('View Details',
                        maxLines: 1, style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 7),
                _CardAction(
                    tooltip: 'View on map',
                    icon: Icons.map_rounded,
                    onPressed: onMap),
                _CardAction(
                    tooltip: 'Directions',
                    icon: Icons.directions_rounded,
                    onPressed: onDirections),
                _CardAction(
                    tooltip: 'Add to Itinerary',
                    icon: Icons.playlist_add_rounded,
                    onPressed: onItinerary),
                _CardAction(
                  tooltip: isFavorite ? 'Remove Favorite' : 'Add Favorite',
                  icon: favoriteBusy
                      ? Icons.hourglass_top_rounded
                      : isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                  onPressed: favoriteBusy ? null : onFavorite,
                ),
              ]),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: .04);
  }
}

class _DiscoveryTile extends StatelessWidget {
  const _DiscoveryTile({
    required this.place,
    required this.distanceKm,
    required this.onTap,
    required this.onMap,
  });

  final MapMarker place;
  final double? distanceKm;
  final VoidCallback onTap;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final accent = placeCategoryColor(place.markerColor);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 244,
        padding: const EdgeInsets.all(12),
        decoration: _glass(radius: 20, accent: accent),
        child: Row(children: [
          Container(
            width: 66,
            height: double.infinity,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: place.images.isEmpty
                ? Icon(placeCategoryIcon(place.categoryIcon),
                    color: accent, size: 32)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: place.images.first,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                          placeCategoryIcon(place.categoryIcon),
                          color: accent),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(place.categoryName ?? 'Place',
                    maxLines: 1,
                    style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (distanceKm != null)
                  Text(_distanceLabel(distanceKm!),
                      style: const TextStyle(
                          color: Color(0xFF38BDF8), fontSize: 10)),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'View on map',
                    visualDensity: VisualDensity.compact,
                    onPressed: onMap,
                    icon: const Icon(Icons.map_rounded,
                        color: Color(0xFFF59E0B), size: 20),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: .9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .7)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 8, fontWeight: FontWeight.w900)),
          ),
        ]),
      );
}

class _CardAction extends StatelessWidget {
  const _CardAction(
      {required this.tooltip, required this.icon, this.onPressed});
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      );
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(
            fixedSize: const Size(50, 50),
            backgroundColor:
                active ? const Color(0xFFF59E0B) : const Color(0xFF0F172A),
            foregroundColor: active ? Colors.black : const Color(0xFFF59E0B),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      );
}

class _ExploreError extends StatelessWidget {
  const _ExploreError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 58, color: Color(0xFF64748B)),
            const SizedBox(height: 14),
            const Text('Unable to load places.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('Check your connection and try again.',
                style: TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}

class _ExploreEmpty extends StatelessWidget {
  const _ExploreEmpty();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off_rounded, size: 58, color: Color(0xFF64748B)),
            SizedBox(height: 14),
            Text('No places found in this category.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Try another category or search term.',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ]),
        ),
      );
}

BoxDecoration _glass({required double radius, Color? accent}) => BoxDecoration(
      color: const Color(0xFF0F172A).withValues(alpha: .96),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: (accent ?? const Color(0xFF334155)).withValues(alpha: .55)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 18,
            offset: const Offset(0, 7)),
      ],
    );

String _distanceLabel(double distanceKm) => distanceKm < 1
    ? '${(distanceKm * 1000).round()} m away'
    : '${distanceKm.toStringAsFixed(1)} km away';
