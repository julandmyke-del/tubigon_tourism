import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/location/tubigon_boundary.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/private_session_data_service.dart';
import '../../authentication/auth_provider.dart';

enum MapMarkerCategory {
  touristSpot,
  msme,
  tourismListing,
  mapLocation,
  wasteReport,
  emergency,
  ecoZone,
}

class MapMarker {
  const MapMarker({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.sourceIntegerId,
    this.address,
    this.aliases = const [],
    this.categoryName,
    this.images = const [],
    this.rating,
    this.reviewCount,
    this.operatingHours,
    this.contact,
    this.status,
    this.isVerified = false,
    this.isOwned = false,
    this.mapLocationId,
    this.emergencyContactId,
    this.categorySlug = 'important-places',
    this.categoryKeys = const ['important-places'],
    this.categoryIcon = 'place',
    this.markerColor = '#F59E0B',
    this.categorySortOrder = 999,
    this.isFeatured = false,
    this.isPreapproved = false,
    this.isActive = true,
    this.isPublished = true,
    this.isBookable = false,
    this.bookingEnabled = false,
    this.bookingUnavailableReasonCode,
    this.bookingUnavailableReason,
    this.viewCount = 0,
    this.createdAt,
  });

  final String id;
  final String sourceId;
  final int? sourceIntegerId;
  final String name;
  final String description;
  final String? address;
  final List<String> aliases;
  final double latitude;
  final double longitude;
  final MapMarkerCategory category;
  final String? categoryName;
  final List<String> images;
  final double? rating;
  final int? reviewCount;
  final String? operatingHours;
  final String? contact;
  final String? status;
  final bool isVerified;
  final bool isOwned;
  final String? mapLocationId;
  final String? emergencyContactId;
  final String categorySlug;
  final List<String> categoryKeys;
  final String categoryIcon;
  final String markerColor;
  final int categorySortOrder;
  final bool isFeatured;
  final bool isPreapproved;
  final bool isActive;
  final bool isPublished;
  final bool isBookable;
  final bool bookingEnabled;
  final String? bookingUnavailableReasonCode;
  final String? bookingUnavailableReason;
  final int viewCount;
  final DateTime? createdAt;

  bool get isFavoritable =>
      category == MapMarkerCategory.touristSpot ||
      category == MapMarkerCategory.msme ||
      category == MapMarkerCategory.tourismListing ||
      category == MapMarkerCategory.mapLocation;

  bool get isEmergencyFacility =>
      category == MapMarkerCategory.emergency || categorySlug == 'emergency';

  bool get hasCallableContact =>
      isEmergencyFacility && (contact?.trim().isNotEmpty ?? false);

  bool get hasFerrySchedules => categorySlug == 'port-transport';

  bool get hasCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);

  bool isWithinMapScope(TubigonBoundary boundary) =>
      hasCoordinates &&
      (boundary.contains(latitude: latitude, longitude: longitude) ||
          (hasFerrySchedules &&
              boundary.containsPortServiceArea(
                  latitude: latitude, longitude: longitude)) ||
          (category == MapMarkerCategory.touristSpot && isPreapproved));

  bool get isItineraryEligible =>
      hasCoordinates &&
      !isEmergencyFacility &&
      (category == MapMarkerCategory.touristSpot ||
          category == MapMarkerCategory.msme ||
          category == MapMarkerCategory.tourismListing ||
          category == MapMarkerCategory.mapLocation);

  String get itineraryEntityType => switch (category) {
        MapMarkerCategory.touristSpot => 'tourist_spot',
        MapMarkerCategory.msme => 'msme',
        MapMarkerCategory.tourismListing => 'tourism_listing',
        MapMarkerCategory.mapLocation => 'map_location',
        _ => '',
      };

  String get itineraryEntityId => category == MapMarkerCategory.mapLocation
      ? (mapLocationId ?? sourceId)
      : sourceId;

  String get favoriteType => switch (category) {
        MapMarkerCategory.touristSpot => 'spot',
        MapMarkerCategory.msme => 'msme',
        MapMarkerCategory.tourismListing => 'tourism_listing',
        MapMarkerCategory.mapLocation => 'map_location',
        _ => '',
      };

  factory MapMarker.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    return MapMarker(
      id: json['id']?.toString() ?? '',
      sourceId: json['source_id']?.toString() ?? '',
      sourceIntegerId: _asInt(json['source_integer_id']),
      name: json['name']?.toString() ?? 'Unnamed location',
      description: json['description']?.toString() ?? '',
      address: json['address']?.toString(),
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      category: _categoryFromType(type),
      categoryName: json['category']?.toString(),
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      rating: _asDouble(json['rating']),
      reviewCount: _asInt(json['review_count']),
      operatingHours: json['operating_hours']?.toString(),
      contact: json['contact']?.toString(),
      status: json['status']?.toString(),
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      isOwned: json['is_owned'] == true || json['is_owned'] == 1,
      mapLocationId: json['map_location_id']?.toString(),
      emergencyContactId: json['emergency_contact_id']?.toString(),
      categorySlug:
          json['category_slug']?.toString() ?? _fallbackCategorySlug(type),
      categoryKeys: (json['category_keys'] as List<dynamic>? ??
              [_fallbackCategorySlug(type)])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      categoryIcon: json['category_icon']?.toString() ?? 'place',
      markerColor: json['marker_color']?.toString() ?? '#F59E0B',
      categorySortOrder: _asInt(json['category_sort_order']) ?? 999,
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
      isPreapproved:
          json['is_preapproved'] == true || json['is_preapproved'] == 1,
      isActive: json['is_active'] == null ||
          json['is_active'] == true ||
          json['is_active'] == 1,
      isPublished: json['is_published'] == null ||
          json['is_published'] == true ||
          json['is_published'] == 1,
      isBookable: json['is_bookable'] == true || json['is_bookable'] == 1,
      bookingEnabled:
          json['booking_enabled'] == true || json['booking_enabled'] == 1,
      bookingUnavailableReasonCode:
          json['booking_unavailable_reason_code']?.toString(),
      bookingUnavailableReason: json['booking_unavailable_reason']?.toString(),
      viewCount: _asInt(json['view_count']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_id': sourceId,
        'source_integer_id': sourceIntegerId,
        'type': category.name,
        'name': name,
        'description': description,
        'address': address,
        'aliases': aliases,
        'latitude': latitude,
        'longitude': longitude,
        'category': categoryName,
        'images': images,
        'rating': rating,
        'review_count': reviewCount,
        'operating_hours': operatingHours,
        'contact': contact,
        'status': status,
        'is_verified': isVerified,
        'is_owned': isOwned,
        'map_location_id': mapLocationId,
        'emergency_contact_id': emergencyContactId,
        'category_slug': categorySlug,
        'category_keys': categoryKeys,
        'category_icon': categoryIcon,
        'marker_color': markerColor,
        'category_sort_order': categorySortOrder,
        'is_featured': isFeatured,
        'is_preapproved': isPreapproved,
        'is_active': isActive,
        'is_published': isPublished,
        'is_bookable': isBookable,
        'booking_enabled': bookingEnabled,
        'booking_unavailable_reason_code': bookingUnavailableReasonCode,
        'booking_unavailable_reason': bookingUnavailableReason,
        'view_count': viewCount,
        'created_at': createdAt?.toIso8601String(),
      };

  bool get canAcceptBookings => isBookable && bookingEnabled;

  String get bookingUnavailableLabel {
    final code = bookingUnavailableReasonCode?.trim();
    if (code == null || code.isEmpty) return 'Temporarily unavailable';
    return code
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  double distanceTo(double lat, double lng) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat - latitude);
    final dLng = _toRadians(lng - longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(latitude)) *
            cos(_toRadians(lat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  static MapMarkerCategory _categoryFromType(String type) {
    switch (type) {
      case 'tourist_spot':
      case 'touristSpot':
        return MapMarkerCategory.touristSpot;
      case 'msme':
        return MapMarkerCategory.msme;
      case 'tourism_listing':
      case 'tourismListing':
        return MapMarkerCategory.tourismListing;
      case 'map_location':
      case 'mapLocation':
        return MapMarkerCategory.mapLocation;
      case 'waste_report':
      case 'wasteReport':
        return MapMarkerCategory.wasteReport;
      case 'emergency':
        return MapMarkerCategory.emergency;
      default:
        return MapMarkerCategory.ecoZone;
    }
  }

  static double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static String _fallbackCategorySlug(String type) => switch (type) {
        'tourist_spot' || 'touristSpot' => 'tourist-spots',
        'msme' => 'msmes',
        'tourism_listing' || 'tourismListing' => 'important-places',
        'waste_report' || 'wasteReport' => 'waste-reports',
        'emergency' => 'emergency',
        _ => 'important-places',
      };
}

class MapPlaceCategory {
  const MapPlaceCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.markerColor,
    required this.sortOrder,
    this.parentId,
    this.active = true,
  });

  final String id;
  final String name;
  final String slug;
  final String icon;
  final String markerColor;
  final int sortOrder;
  final String? parentId;
  final bool active;

  factory MapPlaceCategory.fromJson(Map<String, dynamic> json) =>
      MapPlaceCategory(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Places',
        slug: json['slug']?.toString() ?? 'important-places',
        icon: json['icon']?.toString() ?? 'place',
        markerColor: json['marker_color']?.toString() ?? '#F59E0B',
        sortOrder: MapMarker._asInt(json['sort_order']) ?? 999,
        parentId: json['parent_id']?.toString(),
        active: json['active'] == null ||
            json['active'] == true ||
            json['active'] == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'icon': icon,
        'marker_color': markerColor,
        'sort_order': sortOrder,
        'parent_id': parentId,
        'active': active,
      };
}

class MapRepository {
  const MapRepository(this._client);

  final ApiClient _client;

  Future<List<MapMarker>> getLocations(
    AuthState auth, {
    bool forceOffline = false,
  }) async {
    final cacheKey = PrivateSessionDataService.mapCacheKey(
      isLoggedIn: auth.isLoggedIn,
      role: auth.role.name,
      userId: auth.userId,
    );
    final storage = LocalStorageService.instance;
    final boundary = await TubigonBoundary.load();

    if (!forceOffline && await checkConnectivity()) {
      try {
        final endpoint = auth.isLoggedIn
            ? ApiEndpoints.authenticatedMapLocations
            : ApiEndpoints.mapLocations;
        final response = await _client.get(endpoint);
        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final raw = (response.data['data'] as List<dynamic>? ?? const []);
          final locations = _safeUniqueMarkers(
            raw.whereType<Map<String, dynamic>>().map(MapMarker.fromJson),
            boundary,
          );
          if (kDebugMode && locations.isEmpty) {
            debugPrint('[MAP] Map API returned 0 public markers for '
                '${auth.role.name}. No data was fabricated locally.');
          }
          await storage.setString(
            cacheKey,
            jsonEncode(locations.map((item) => item.toJson()).toList()),
          );
          return locations;
        }
      } catch (error) {
        debugPrint(
            '[MAP] Remote map feed unavailable; using role cache: $error');
      }
    }

    final cached = storage.getString(cacheKey);
    if (cached == null || cached.isEmpty) return const [];
    try {
      return _safeUniqueMarkers(
        (jsonDecode(cached) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(MapMarker.fromJson),
        boundary,
      );
    } catch (error) {
      debugPrint('[MAP] Invalid cached map data: $error');
      return const [];
    }
  }

  List<MapMarker> _safeUniqueMarkers(
    Iterable<MapMarker> markers,
    TubigonBoundary boundary,
  ) {
    final seen = <String>{};
    return markers.where((item) {
      if (!item.isWithinMapScope(boundary)) return false;
      final id = item.id.trim();
      final sourceId = item.sourceId.trim();
      final identity = id.isNotEmpty
          ? id
          : sourceId.isNotEmpty
              ? '${item.category.name}:$sourceId'
              : '${item.category.name}:${item.latitude}:${item.longitude}:${item.name}';
      return seen.add(identity);
    }).toList(growable: false);
  }

  Future<List<MapPlaceCategory>> getCategories(
      {bool forceOffline = false}) async {
    const cacheKey = 'smart_map_categories_cache';
    final storage = LocalStorageService.instance;
    if (!forceOffline && await checkConnectivity()) {
      try {
        final response = await _client.get(ApiEndpoints.placeCategories);
        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final categories = (response.data['data'] as List<dynamic>? ??
                  const [])
              .whereType<Map<String, dynamic>>()
              .map(MapPlaceCategory.fromJson)
              .toList(growable: false)
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          await storage.setString(cacheKey,
              jsonEncode(categories.map((item) => item.toJson()).toList()));
          return categories;
        }
      } catch (error) {
        debugPrint('[MAP] Category feed unavailable; using cache: $error');
      }
    }
    final cached = storage.getString(cacheKey);
    if (cached == null || cached.isEmpty) return const [];
    try {
      return (jsonDecode(cached) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MapPlaceCategory.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

class UserLocationState {
  const UserLocationState({
    this.latitude,
    this.longitude,
    this.isTracking = false,
    this.isLoading = false,
    this.error,
    this.isWithinTubigon,
  });

  final double? latitude;
  final double? longitude;
  final bool isTracking;
  final bool isLoading;
  final String? error;
  final bool? isWithinTubigon;

  bool get hasLocation => latitude != null && longitude != null;

  UserLocationState copyWith({
    double? latitude,
    double? longitude,
    bool? isTracking,
    bool? isLoading,
    String? error,
    bool? isWithinTubigon,
  }) =>
      UserLocationState(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        isTracking: isTracking ?? this.isTracking,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isWithinTubigon: isWithinTubigon ?? this.isWithinTubigon,
      );
}

class NavigationState {
  const NavigationState({
    this.destination,
    this.isNavigating = false,
    this.distanceKm,
    this.etaMinutes,
  });

  final MapMarker? destination;
  final bool isNavigating;
  final double? distanceKm;
  final int? etaMinutes;

  NavigationState copyWith({
    MapMarker? destination,
    bool? isNavigating,
    double? distanceKm,
    int? etaMinutes,
  }) =>
      NavigationState(
        destination: destination ?? this.destination,
        isNavigating: isNavigating ?? this.isNavigating,
        distanceKm: distanceKm ?? this.distanceKm,
        etaMinutes: etaMinutes ?? this.etaMinutes,
      );
}

class MapFilterState {
  const MapFilterState({
    this.searchQuery = '',
    this.activeCategoryKeys = const <String>{},
  });

  final String searchQuery;
  final Set<String> activeCategoryKeys;

  bool get isActive =>
      searchQuery.trim().isNotEmpty || activeCategoryKeys.isNotEmpty;

  MapFilterState copyWith({
    String? searchQuery,
    Set<String>? activeCategoryKeys,
  }) =>
      MapFilterState(
        searchQuery: searchQuery ?? this.searchQuery,
        activeCategoryKeys: activeCategoryKeys ?? this.activeCategoryKeys,
      );
}

/// Applies the public Smart Map visibility rules to authoritative map-feed
/// markers. This function is shared by the provider and search suggestions so
/// those surfaces cannot drift into different matching behavior.
List<MapMarker> filterMapMarkers(
  Iterable<MapMarker> markers,
  MapFilterState filter,
) {
  final activeKeys = filter.activeCategoryKeys
      .map((key) => key.trim().toLowerCase())
      .where((key) => key.isNotEmpty)
      .toSet();
  final query = filter.searchQuery.trim().toLowerCase();

  return markers.where((item) {
    if (!item.hasCoordinates) return false;
    if (activeKeys.isNotEmpty) {
      final categoryMatches =
          activeKeys.contains(item.categorySlug.trim().toLowerCase()) ||
              item.categoryKeys.any(
                (key) => activeKeys.contains(key.trim().toLowerCase()),
              );
      if (!categoryMatches) return false;
    }
    if (query.isEmpty) return true;
    return item.name.toLowerCase().contains(query) ||
        item.aliases.any((alias) => alias.toLowerCase().contains(query)) ||
        item.description.toLowerCase().contains(query) ||
        (item.address?.toLowerCase().contains(query) ?? false) ||
        (item.categoryName?.toLowerCase().contains(query) ?? false) ||
        item.categorySlug.toLowerCase().contains(query) ||
        item.categoryKeys.any((key) => key.toLowerCase().contains(query));
  }).toList(growable: false);
}

bool mapMarkerMatchesFocus(MapMarker marker, String focus) {
  final normalized = focus.trim().toLowerCase();
  return marker.id.toLowerCase() == normalized ||
      marker.sourceId.toLowerCase() == normalized ||
      marker.name.toLowerCase() == normalized;
}

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return MapRepository(ref.watch(apiClientProvider));
});

final mapFilterProvider =
    StateProvider<MapFilterState>((ref) => const MapFilterState());
final offlineMapModeProvider = StateProvider<bool>((ref) => false);

final mapMarkersProvider = FutureProvider<List<MapMarker>>((ref) {
  ref.watch(connectivityProvider);
  final forceOffline = ref.watch(offlineMapModeProvider);
  final auth = ref.watch(authProvider);
  return ref
      .watch(mapRepositoryProvider)
      .getLocations(auth, forceOffline: forceOffline);
});

final mapPlaceCategoriesProvider =
    FutureProvider<List<MapPlaceCategory>>((ref) {
  ref.watch(connectivityProvider);
  final forceOffline = ref.watch(offlineMapModeProvider);
  return ref
      .watch(mapRepositoryProvider)
      .getCategories(forceOffline: forceOffline);
});

final filteredMapMarkersProvider = Provider<AsyncValue<List<MapMarker>>>((ref) {
  final markers = ref.watch(mapMarkersProvider);
  final filter = ref.watch(mapFilterProvider);
  return markers.whenData((items) => filterMapMarkers(items, filter));
});

abstract interface class LocationGateway {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> currentPosition();
  Stream<Position> positionStream();
}

class GeolocatorLocationGateway implements LocationGateway {
  const GeolocatorLocationGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> currentPosition() => Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

  @override
  Stream<Position> positionStream() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
}

class UserLocationNotifier extends StateNotifier<UserLocationState> {
  UserLocationNotifier([LocationGateway? gateway])
      : _gateway = gateway ?? const GeolocatorLocationGateway(),
        super(const UserLocationState());

  final LocationGateway _gateway;
  StreamSubscription<Position>? _positionStream;
  int _locationGeneration = 0;
  bool _disposed = false;

  UserLocationState get current => state;

  Future<bool> locate({bool track = false}) async {
    if (_disposed) return false;
    final generation = ++_locationGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (!await _gateway.isServiceEnabled()) {
        if (!_isCurrent(generation)) return false;
        state = state.copyWith(
          isLoading: false,
          isTracking: false,
          error: 'Location services are disabled. Enable GPS and try again.',
        );
        return false;
      }

      var permission = await _gateway.checkPermission();
      if (!_isCurrent(generation)) return false;
      if (permission == LocationPermission.denied) {
        permission = await _gateway.requestPermission();
        if (!_isCurrent(generation)) return false;
      }
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          isLoading: false,
          isTracking: false,
          error: 'Location permission was denied.',
        );
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          isTracking: false,
          error:
              'Location permission is permanently denied. Open app settings to allow it.',
        );
        return false;
      }

      final position = await _gateway.currentPosition();
      if (!_isCurrent(generation)) return false;
      final boundary = await TubigonBoundary.load();
      if (!_isCurrent(generation)) return false;
      state = UserLocationState(
        latitude: position.latitude,
        longitude: position.longitude,
        isTracking: track,
        isWithinTubigon: boundary.contains(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      if (track) _startPositionStream(boundary, generation);
      return true;
    } catch (error) {
      if (!_isCurrent(generation)) return false;
      state = state.copyWith(
        isLoading: false,
        isTracking: false,
        error: 'Unable to determine your location. Please try again.',
      );
      debugPrint('[GPS] $error');
      return false;
    }
  }

  Future<void> startTracking() async => locate(track: true);

  bool _isCurrent(int generation) =>
      !_disposed && generation == _locationGeneration;

  void _startPositionStream(TubigonBoundary boundary, int generation) {
    unawaited(_positionStream?.cancel());
    _positionStream = _gateway.positionStream().listen((position) {
      if (!_isCurrent(generation)) return;
      state = UserLocationState(
        latitude: position.latitude,
        longitude: position.longitude,
        isTracking: true,
        isWithinTubigon: boundary.contains(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    }, onError: (Object error) {
      debugPrint('[GPS] Position stream error: $error');
    });
  }

  void stopTracking() {
    _locationGeneration++;
    unawaited(_positionStream?.cancel());
    _positionStream = null;
    if (!_disposed) {
      state = state.copyWith(isTracking: false, isLoading: false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _locationGeneration++;
    unawaited(_positionStream?.cancel());
    _positionStream = null;
    super.dispose();
  }
}

final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, UserLocationState>((ref) {
  return UserLocationNotifier();
});

final navigationProvider =
    StateProvider<NavigationState>((ref) => const NavigationState());
final selectedMarkerProvider = StateProvider<MapMarker?>((ref) => null);
