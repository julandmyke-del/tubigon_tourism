import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../authentication/auth_provider.dart';
import '../providers/map_provider.dart';

class ManagedMapLocation {
  const ManagedMapLocation({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.verified,
    required this.published,
    required this.active,
    this.description,
    this.address,
    this.latitude,
    this.longitude,
    this.subcategoryId,
    this.entityType,
    this.entityId,
    this.markerIcon,
    this.imageUrl,
    this.isFeatured = false,
    this.categoryName,
    this.subcategoryName,
  });

  final String id;
  final String name;
  final String? description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String categoryId;
  final String? subcategoryId;
  final String? entityType;
  final String? entityId;
  final String? markerIcon;
  final String? imageUrl;
  final bool isFeatured;
  final bool verified;
  final bool published;
  final bool active;
  final String? categoryName;
  final String? subcategoryName;

  factory ManagedMapLocation.fromJson(Map<String, dynamic> json) {
    double? number(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    final category = json['category'] as Map<String, dynamic>?;
    final subcategory = json['subcategory'] as Map<String, dynamic>?;
    return ManagedMapLocation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed place',
      description: json['description']?.toString(),
      address: json['address']?.toString(),
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
      categoryId: json['category_id']?.toString() ?? '',
      subcategoryId: json['subcategory_id']?.toString(),
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id']?.toString(),
      markerIcon: json['marker_icon']?.toString(),
      imageUrl: json['image_url']?.toString(),
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
      verified: json['verified'] == true || json['verified'] == 1,
      published: json['published'] == true || json['published'] == 1,
      active: json['active'] == true || json['active'] == 1,
      categoryName: category?['name']?.toString(),
      subcategoryName: subcategory?['name']?.toString(),
    );
  }
}

class LinkedPlaceOption {
  const LinkedPlaceOption(
      {required this.id, required this.name, this.latitude, this.longitude});
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  factory LinkedPlaceOption.fromJson(Map<String, dynamic> json) {
    double? number(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return LinkedPlaceOption(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? json['listing_name'] ?? 'Unnamed').toString(),
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
    );
  }
}

class PossibleDuplicateException implements Exception {
  const PossibleDuplicateException(this.matches);
  final List<Map<String, dynamic>> matches;
}

class MapLocationManagementRepository {
  const MapLocationManagementRepository(this._client, this._ref);

  final ApiClient _client;
  final Ref _ref;

  String get _scope {
    final role = _ref.read(authProvider).role;
    if (role == UserRole.admin) return 'admin';
    if (role == UserRole.lguStaff) return 'lgu';
    throw StateError('Map location management requires LGU or Admin access.');
  }

  Future<List<ManagedMapLocation>> getLocations() async {
    final response =
        await _client.get(ApiEndpoints.managedMapLocations(_scope));
    return (response.data['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ManagedMapLocation.fromJson)
        .toList(growable: false);
  }

  Future<List<MapPlaceCategory>> getCategories() async {
    final response =
        await _client.get(ApiEndpoints.managedMapLocationCategories(_scope));
    return (response.data['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MapPlaceCategory.fromJson)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<Map<String, List<LinkedPlaceOption>>> getLinkOptions() async {
    final responses = await Future.wait([
      _client.get(ApiEndpoints.touristSpots),
      _client.get(ApiEndpoints.msmes),
      _client.get(_scope == 'admin'
          ? ApiEndpoints.adminEmergencyContacts
          : ApiEndpoints.lguEmergencyContacts),
    ]);
    List<LinkedPlaceOption> parse(dynamic value) =>
        (value as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LinkedPlaceOption.fromJson)
            .toList(growable: false);
    return {
      'tourist_spot': parse(responses[0].data['data']),
      'msme': parse(responses[1].data['data']),
      'emergency_contact': parse(responses[2].data['data']),
    };
  }

  Future<ManagedMapLocation> save(Map<String, dynamic> payload,
      {String? id, bool overrideDuplicate = false}) async {
    if (!overrideDuplicate) {
      final check = await _client.post(
        '${ApiEndpoints.managedMapLocations(_scope)}/duplicates',
        data: {
          'name': payload['name'],
          'latitude': payload['latitude'],
          'longitude': payload['longitude'],
          'entity_type': payload['entity_type'],
          'entity_id': payload['entity_id'],
          if (id != null) 'exclude_id': id,
        },
      );
      final matches = (check.data['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      if (matches.isNotEmpty) throw PossibleDuplicateException(matches);
    }
    final data = {...payload, 'duplicate_override': overrideDuplicate};
    final response = id == null
        ? await _client.post(ApiEndpoints.managedMapLocations(_scope),
            data: data)
        : await _client.put(ApiEndpoints.managedMapLocation(_scope, id),
            data: data);
    return ManagedMapLocation.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<void> verify(String id, bool value) => _client.patch(
        ApiEndpoints.managedMapLocationAction(_scope, id, 'verify'),
        data: {'verified': value},
      );

  Future<void> publish(String id, bool value) => _client.patch(
        ApiEndpoints.managedMapLocationAction(_scope, id, 'publish'),
        data: {'published': value},
      );

  Future<void> setActive(String id, bool value) => _client.patch(
        ApiEndpoints.managedMapLocationAction(_scope, id, 'status'),
        data: {'active': value},
      );

  Future<void> archive(String id) =>
      _client.delete(ApiEndpoints.managedMapLocation(_scope, id));

  Future<void> saveCategory(Map<String, dynamic> data, {String? id}) async {
    final endpoint = ApiEndpoints.managedMapLocationCategories(_scope);
    if (id == null) {
      await _client.post(endpoint, data: data);
    } else {
      await _client.put('$endpoint/$id', data: data);
    }
  }
}

final mapLocationManagementRepositoryProvider =
    Provider<MapLocationManagementRepository>((ref) {
  return MapLocationManagementRepository(ref.watch(apiClientProvider), ref);
});

final managedMapLocationsProvider =
    FutureProvider.autoDispose<List<ManagedMapLocation>>((ref) {
  return ref.watch(mapLocationManagementRepositoryProvider).getLocations();
});

final managedMapCategoriesProvider =
    FutureProvider.autoDispose<List<MapPlaceCategory>>((ref) {
  return ref.watch(mapLocationManagementRepositoryProvider).getCategories();
});

final mapLinkOptionsProvider =
    FutureProvider.autoDispose<Map<String, List<LinkedPlaceOption>>>((ref) {
  return ref.watch(mapLocationManagementRepositoryProvider).getLinkOptions();
});
