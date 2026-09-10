import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class TourismPartnerRepository {
  TourismPartnerRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> getDashboardStats() =>
      _map(ApiEndpoints.partnerDashboardStats);

  Future<Map<String, dynamic>?> getCurrentAssignment() =>
      _nullableMap(ApiEndpoints.partnerAssignment);

  Future<List<Map<String, dynamic>>> getRecentActivity() =>
      _list(ApiEndpoints.partnerActivity);

  Future<List<Map<String, dynamic>>> getMyListings() async =>
      (await _list(ApiEndpoints.partnerListings))
          .map(_listingDto)
          .toList(growable: false);

  Future<Map<String, dynamic>> getListingById(String listingId) async =>
      _listingDto(await _map(ApiEndpoints.partnerListing(listingId)));

  Future<List<Map<String, dynamic>>> getManagedDestinations() =>
      _list(ApiEndpoints.partnerTouristSpots);

  Future<Map<String, dynamic>> getManagedDestination(String spotId) =>
      _map(ApiEndpoints.partnerTouristSpot(spotId));

  Future<void> updateManagedDestination(
    String spotId,
    Map<String, dynamic> data,
  ) =>
      _write(apiClient.patch(
        ApiEndpoints.partnerTouristSpot(spotId),
        data: data,
      ));

  Future<void> updateBookingAvailability(
    String spotId, {
    required bool enabled,
    String? reasonCode,
    String? reason,
  }) =>
      _write(apiClient.patch(
        ApiEndpoints.partnerTouristSpotBookingAvailability(spotId),
        data: {
          'booking_enabled': enabled,
          if (!enabled) 'reason_code': reasonCode,
          if (!enabled && reason?.trim().isNotEmpty == true)
            'reason': reason!.trim(),
        },
      ));

  Future<void> createListing(Map<String, dynamic> listingData) =>
      _write(apiClient.post(ApiEndpoints.partnerListings, data: listingData));

  Future<void> updateListing(
    String listingId,
    Map<String, dynamic> listingData,
  ) =>
      _write(apiClient.put(
        ApiEndpoints.partnerListing(listingId),
        data: listingData,
      ));

  Future<void> submitListing(String listingId) =>
      _write(apiClient.post(ApiEndpoints.partnerSubmitListing(listingId)));

  Future<void> deleteListing(String listingId) =>
      _write(apiClient.delete(ApiEndpoints.partnerListing(listingId)));

  Future<Map<String, dynamic>> getReservationQueue({
    String? statusFilter,
    String? search,
    String? scope,
    String? from,
    String? to,
    String sort = 'visit_asc',
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.partnerReservations,
      queryParameters: {
        if (statusFilter != null && statusFilter.toLowerCase() != 'all')
          'status_filter': statusFilter.toLowerCase(),
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        if (scope?.isNotEmpty == true) 'scope': scope,
        if (from?.isNotEmpty == true) 'from': from,
        if (to?.isNotEmpty == true) 'to': to,
        'sort': sort,
      },
    );
    _assertSuccess(response);
    final rows = response.data['data'];
    if (rows is! List) throw const FormatException('Invalid API response.');
    final meta = response.data['meta'];
    return {
      'items': rows
          .whereType<Map>()
          .map((row) => _reservationDto(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      'summary': meta is Map && meta['summary'] is Map
          ? Map<String, dynamic>.from(meta['summary'] as Map)
          : <String, dynamic>{},
    };
  }

  Future<List<Map<String, dynamic>>> getReservations(
          {String? statusFilter}) async =>
      ((await getReservationQueue(statusFilter: statusFilter))['items'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

  Future<Map<String, dynamic>> getReservationById(String reservationId) async =>
      _reservationDto(
          await _map(ApiEndpoints.partnerReservation(reservationId)));

  Future<void> updateReservationStatus(
    String reservationId,
    String statusName, {
    String? reason,
  }) =>
      _write(apiClient.put(
        ApiEndpoints.partnerReservationStatus(reservationId),
        data: {
          'status_name': statusName.toLowerCase(),
          if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
        },
      ));

  Future<List<Map<String, dynamic>>> getNotifications(
          {String filter = 'all'}) =>
      _list(ApiEndpoints.partnerNotifications,
          queryParameters: {'filter': filter});

  Future<void> markNotificationRead(String notificationId) => _write(
      apiClient.put(ApiEndpoints.partnerNotificationRead(notificationId)));

  Future<void> markAllNotificationsRead() =>
      _write(apiClient.put(ApiEndpoints.partnerNotificationsReadAll));

  Future<void> deleteNotification(String notificationId) => _write(
      apiClient.delete(ApiEndpoints.partnerNotification(notificationId)));

  Future<List<Map<String, dynamic>>> getListingReviews() async {
    final rows = await _list(ApiEndpoints.partnerReviews);
    return rows.map((row) {
      final user = row['user'];
      return {
        ...row,
        'reviewer': user is Map ? user['name'] : 'Tourist',
        'comment': row['content'],
        'date': row['created_at'],
      };
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> getReviewStats() =>
      _map(ApiEndpoints.partnerReviewStats);

  Future<Map<String, dynamic>> getAnalytics({
    String period = '30_days',
    String? from,
    String? to,
  }) =>
      _map(ApiEndpoints.partnerAnalytics, queryParameters: {
        'period': period,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      });

  Future<Map<String, dynamic>> getProfile() =>
      _map(ApiEndpoints.partnerProfile);

  Future<void> updateProfile(Map<String, dynamic> profileData) =>
      _write(apiClient.put(ApiEndpoints.partnerProfile, data: profileData));

  Future<void> updatePassword(String newPassword) =>
      _write(apiClient.put(ApiEndpoints.partnerPassword, data: {
        'password': newPassword,
        'password_confirmation': newPassword,
      }));

  Future<String> uploadListingImage(
      String fileName, List<int> fileBytes) async {
    final response = await apiClient.post(
      ApiEndpoints.partnerImageUpload,
      data: FormData.fromMap({
        'image': MultipartFile.fromBytes(fileBytes, filename: fileName),
      }),
    );
    _assertSuccess(response);
    final url = response.data['data']?['url']?.toString();
    if (url == null || url.isEmpty) {
      throw const FormatException('Missing image URL.');
    }
    return url;
  }

  Map<String, dynamic> _listingDto(Map<String, dynamic> row) => {
        ...row,
        'name': row['listing_name'],
        'category': row['listing_type'],
        'location': row['address'],
        'status': row['approval_status'] ?? row['status'],
        'rating': row['average_rating'] ?? 0,
      };

  Map<String, dynamic> _reservationDto(Map<String, dynamic> row) {
    final status = row['status'];
    final user = row['user'];
    final listing = row['listing'];
    return {
      ...row,
      'status': status is Map ? status['name'] : status,
      'guest_name': row['customer'] is Map
          ? (row['customer'] as Map)['name']
          : (user is Map ? user['name'] : null),
      'listing_name': row['reservable_name'] ??
          (listing is Map ? listing['listing_name'] : null),
      'date': row['reservation_date'],
      'time': row['start_time'],
    };
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

  Future<Map<String, dynamic>?> _nullableMap(String endpoint) async {
    final response = await apiClient.get(endpoint);
    _assertSuccess(response);
    final data = response.data['data'];
    if (data == null) return null;
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

  Future<void> _write(Future<Response<dynamic>> operation) async {
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
