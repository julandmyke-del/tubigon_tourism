import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class MsmePortalRepository {
  MsmePortalRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> getDashboardStats() =>
      _map(ApiEndpoints.msmeDashboardStats);

  /// The current schema models one business per owner. The existing portal's
  /// "listings" surface therefore renders that real business, not fake products.
  Future<List<Map<String, dynamic>>> getMyListings() async {
    final profile = await getProfile();
    return profile.isEmpty ? const [] : [profile];
  }

  Future<void> createListing(Map<String, dynamic> data) async {
    await _success(apiClient.post(ApiEndpoints.createMsmeBusiness, data: data));
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

  Future<void> updateReservationStatus(String id, String status) async {
    await _success(apiClient.put(
      ApiEndpoints.msmePortalUpdateReservationStatus(id),
      data: {'status_name': status.toLowerCase()},
    ));
  }

  Future<List<Map<String, dynamic>>> getReviews() async {
    final data = await _map(ApiEndpoints.msmePortalReviews);
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
    final data = await _map(ApiEndpoints.msmePortalReviews);
    return {
      'averageRating': data['averageRating'] ?? 0,
      'totalReviews': data['reviewCount'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> getAnalytics() =>
      _map(ApiEndpoints.msmePortalAnalytics);

  Future<List<Map<String, dynamic>>> getNotifications() =>
      _list(ApiEndpoints.msmePortalNotifications);

  Future<void> markNotificationRead(String id) =>
      _success(apiClient.put(ApiEndpoints.markRead(id)));

  Future<void> markAllNotificationsRead() =>
      _success(apiClient.put(ApiEndpoints.markAllRead));

  Future<Map<String, dynamic>> getProfile() async {
    final response = await apiClient.get(ApiEndpoints.msmePortalProfile);
    _assertSuccess(response);
    final data = response.data['data'];
    return data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
  }

  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    await _success(apiClient.put(
      ApiEndpoints.msmePortalProfile,
      data: profileData,
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

  Future<Map<String, dynamic>> _map(String endpoint) async {
    final response = await apiClient.get(endpoint);
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
