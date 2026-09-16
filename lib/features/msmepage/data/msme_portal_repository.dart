import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class CurrentMsmeState {
  const CurrentMsmeState(
      {required this.business, required this.profileRequired});

  final Map<String, dynamic>? business;
  final bool profileRequired;

  bool get hasBusiness => business != null;
}

class MsmePortalRepository {
  MsmePortalRepository({required this.apiClient});

  final ApiClient apiClient;
  final Map<String, String> _versions = <String, String>{};

  void _rememberVersion(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final version = row['updated_at']?.toString();
    if (id != null && version != null) _versions[id] = version;
  }

  Future<Map<String, dynamic>> getDashboardStats() =>
      _map(ApiEndpoints.msmeDashboardStats);

  /// The current schema models one business per owner. The existing portal's
  /// "listings" surface therefore renders that real business, not fake products.
  Future<List<Map<String, dynamic>>> getMyListings() async {
    final profile = await getProfile();
    return profile.isEmpty ? const [] : [profile];
  }

  Future<void> createListing(Map<String, dynamic> data,
      {bool saveAsDraft = true}) async {
    await _success(apiClient.post(ApiEndpoints.createMsmeBusiness,
        data: {...data, 'save_as_draft': saveAsDraft}));
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) =>
      updateProfile(data);

  Future<void> deleteListing(String id) =>
      throw UnsupportedError('Business archival is managed by LGU/Admin.');

  Future<void> submitProfile() async {
    await _success(apiClient.post(ApiEndpoints.msmeSubmitProfile));
  }

  Future<List<Map<String, dynamic>>> getReservations(
      {String? statusFilter}) async {
    final rows = await _list(
      ApiEndpoints.msmePortalReservations,
      queryParameters: {
        if (statusFilter != null && statusFilter.toLowerCase() != 'all')
          'status': statusFilter.toLowerCase(),
      },
    );
    for (final row in rows) {
      _rememberVersion(row);
    }
    return rows.map((row) {
      final status = row['status'];
      final user = row['user'];
      return {
        ...row,
        'status': status is Map ? status['name'] : status,
        'guest_name': user is Map ? user['name'] : null,
        'listing_name': row['reservable_name'] ?? 'Business reservation',
        'date': row['reservation_date'],
        'time': row['start_time'],
      };
    }).toList(growable: false);
  }

  Future<void> updateReservationStatus(String id, String status,
      {String? reason}) async {
    await _success(apiClient.put(
      ApiEndpoints.msmePortalUpdateReservationStatus(id),
      data: {
        'status_name': status.toLowerCase(),
        if (reason != null) 'reason': reason,
        if (_versions[id] case final version?) 'expected_updated_at': version,
      },
    ));
  }

  Future<List<Map<String, dynamic>>> getReviews() async {
    final data = await getReviewData();
    final rows = (data['reviews'] as List? ?? const []);
    return rows.whereType<Map>().map((raw) {
      final row = Map<String, dynamic>.from(raw);
      final user = row['user'];
      return {
        ...row,
        'reviewer': user is Map ? user['name'] : 'Tourist',
        'comment': row['content'],
        'date': row['created_at'],
      };
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> getReviewStats() async {
    final data = await getReviewData();
    return {
      'averageRating': data['averageRating'] ?? 0,
      'totalReviews': data['reviewCount'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> getAnalytics({
    String period = '30_days',
    String? from,
    String? to,
  }) =>
      _map(ApiEndpoints.msmePortalAnalytics, queryParameters: {
        'period': period,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      });

  Future<List<Map<String, dynamic>>> getNotifications() =>
      _list(ApiEndpoints.msmePortalNotifications);

  Future<void> markNotificationRead(String id) =>
      _success(apiClient.put(ApiEndpoints.markRead(id)));

  Future<void> markAllNotificationsRead() =>
      _success(apiClient.put(ApiEndpoints.markAllRead));

  Future<Map<String, dynamic>> getProfile() async {
    return (await getCurrentBusiness()).business ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getReviewData() =>
      _map(ApiEndpoints.msmePortalReviews);

  Future<CurrentMsmeState> getCurrentBusiness() async {
    final response = await apiClient.get(ApiEndpoints.msmePortalProfile);
    _assertSuccess(response);
    final data = response.data['data'];
    final business = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : null;
    if (business != null) _rememberVersion(business);
    return CurrentMsmeState(
      business: business,
      profileRequired:
          response.data['profile_required'] == true || business == null,
    );
  }

  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    final id = profileData['id']?.toString() ??
        (_versions.length == 1 ? _versions.keys.single : null);
    final version = profileData['updated_at']?.toString() ??
        (id == null ? null : _versions[id]);
    await _success(apiClient.put(
      ApiEndpoints.msmePortalProfile,
      data: {
        ...profileData,
        if (version != null) 'expected_updated_at': version,
      },
    ));
  }

  Future<String> uploadImage(String fileName, List<int> fileBytes) async {
    final response = await apiClient.post(
      ApiEndpoints.uploadImage,
      data: FormData.fromMap({
        'image': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'bucket': 'msme-gallery',
      }),
    );
    _assertSuccess(response);
    final url = response.data['data']?['url']?.toString();
    if (url == null || url.isEmpty) {
      throw const FormatException('Missing image URL.');
    }
    return url;
  }

  Future<Map<String, dynamic>> _map(String endpoint,
      {Map<String, dynamic>? queryParameters}) async {
    final response =
        await apiClient.get(endpoint, queryParameters: queryParameters);
    _assertSuccess(response);
    final data = response.data['data'];
    if (data is! Map) throw const FormatException('Invalid API response.');
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> _list(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response =
        await apiClient.get(endpoint, queryParameters: queryParameters);
    _assertSuccess(response);
    final data = response.data['data'];
    if (data is! List) throw const FormatException('Invalid API response.');
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> _success(Future<Response<dynamic>> operation) async {
    _assertSuccess(await operation);
  }

  void _assertSuccess(Response<dynamic> response) {
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300 ||
        response.data is! Map ||
        response.data['status'] != 'success') {
      throw StateError(response.data is Map
          ? response.data['message']?.toString() ?? 'Request failed.'
          : 'Request failed.');
    }
  }
}
