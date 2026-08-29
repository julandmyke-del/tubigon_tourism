import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

final lguRepositoryProvider = Provider<LguRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LguRepository(apiClient);
});

/// Official repository for the LGU Staff Module
class LguRepository {
  final ApiClient _apiClient;

  LguRepository(this._apiClient);

  /// Fetch executive municipal dashboard counts & statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _apiClient.get(ApiEndpoints.lguDashboardStats);
    return _map(response);
  }

  /// Update tourist spot status (Active, Maintenance, Inactive)
  Future<bool> updateSpotStatus(String spotId, String status) async {
    final response = await _apiClient.put(
      ApiEndpoints.lguUpdateSpotStatus(spotId),
      data: {'status': status},
    );
    _map(response);
    return true;
  }

  Future<Map<String, dynamic>> updateTouristSpot(
      String spotId, Map<String, dynamic> data) async {
    return _map(await _apiClient.put(
      ApiEndpoints.lguUpdateTouristSpot(spotId),
      data: data,
    ));
  }

  /// Verify, approve, reject, or suspend MSME business registrations
  Future<bool> verifyMsme(
    String msmeId,
    bool isVerified, {
    String? status,
    String? notes,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.lguVerifyMsme(msmeId),
      data: {
        'is_verified': isVerified,
        'verification_status':
            status ?? (isVerified ? 'verified' : 'needs_changes'),
        if (notes != null) 'notes': notes,
      },
    );
    _map(response);
    return true;
  }

  /// Update environmental waste report status, remarks & assigned team
  Future<bool> updateWasteReportStatus(
    String reportId,
    String status, {
    String? remarks,
    String? assignedPersonnel,
    String? assignedTo,
    String? priority,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.lguUpdateWasteStatus(reportId),
      data: {
        'status': status,
        if (remarks != null) 'notes': remarks,
        if (assignedPersonnel != null) 'assigned_personnel': assignedPersonnel,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (priority != null) 'priority': priority,
      },
    );
    _map(response);
    return true;
  }

  /// Fetch municipal tourism analytics & performance metrics
  Future<Map<String, dynamic>> getAnalytics() async {
    return _map(await _apiClient.get(ApiEndpoints.lguAnalytics));
  }

  /// Fetch generated municipal report data (daily, weekly, monthly, yearly)
  Future<Map<String, dynamic>> getReports(String period) async {
    return _map(await _apiClient.get(
      ApiEndpoints.lguReports,
      queryParameters: {'period': period},
    ));
  }

  /// Fetch all waste reports for municipal monitoring
  Future<List<Map<String, dynamic>>> getWasteReports() async {
    return _list(await _apiClient.get(ApiEndpoints.wasteReports));
  }

  Future<Map<String, dynamic>> getWasteReport(String id) async =>
      _map(await _apiClient.get(ApiEndpoints.wasteReportById(id)));

  Future<List<Map<String, dynamic>>> getMsmes({String? status}) async => _list(
        await _apiClient.get(ApiEndpoints.lguMsmes,
            queryParameters: {if (status != null) 'status': status}),
      );

  Future<List<Map<String, dynamic>>> getTouristSpots() async =>
      _list(await _apiClient.get(ApiEndpoints.lguTouristSpots));

  Future<void> updateTouristSpotBooking(
      String id, Map<String, dynamic> configuration) async {
    _map(await _apiClient.put(
      ApiEndpoints.lguUpdateSpotBooking(id),
      data: configuration,
    ));
  }

  Future<void> updateTouristSpotBookingAvailability(
    String id, {
    required bool enabled,
    String? reasonCode,
    String? reason,
  }) async {
    _map(await _apiClient.patch(
      ApiEndpoints.lguTouristSpotBookingAvailability(id),
      data: {
        'booking_enabled': enabled,
        if (!enabled) 'reason_code': reasonCode,
        if (!enabled && reason?.trim().isNotEmpty == true)
          'reason': reason!.trim(),
      },
    ));
  }

  Future<List<Map<String, dynamic>>> getSpotReservations() async =>
      _list(await _apiClient.get(ApiEndpoints.lguReservations));

  Future<List<Map<String, dynamic>>> getReservationStatuses() async =>
      _list(await _apiClient.get(ApiEndpoints.reservationStatuses));

  Future<Map<String, dynamic>> getSpotReservation(String id) async =>
      _map(await _apiClient.get(ApiEndpoints.lguReservation(id)));

  Future<void> updateSpotReservationStatus(String id, String statusId) async {
    _map(await _apiClient.put(
      ApiEndpoints.lguUpdateReservationStatus(id),
      data: {'status_id': statusId},
    ));
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async =>
      _list(await _apiClient.get(ApiEndpoints.announcements));

  Future<List<Map<String, dynamic>>> getEcoTips() async =>
      _list(await _apiClient.get(ApiEndpoints.ecoTips));

  Future<List<Map<String, dynamic>>> getTourismListings(
          {String? status}) async =>
      _list(await _apiClient.get(ApiEndpoints.lguTourismListings,
          queryParameters: {if (status != null) 'status': status}));

  Future<void> reviewTourismListing(
    String id,
    String status, {
    String? notes,
  }) async {
    _map(await _apiClient.put(ApiEndpoints.lguReviewTourismListing(id), data: {
      'approval_status': status,
      if (notes != null) 'notes': notes,
    }));
  }

  /// Moderate community reviews (publish or flag)
  Future<bool> moderateReview(String reviewId, String status) async {
    throw UnsupportedError('LGU review moderation is not enabled.');
  }

  /// Post a new municipal announcement
  Future<bool> createAnnouncement(Map<String, dynamic> data) async {
    throw UnsupportedError('Announcements are read-only for LGU staff.');
  }

  /// Add a new eco-tourism tip
  Future<bool> createEcoTip(Map<String, dynamic> data) async {
    throw UnsupportedError('Eco tips are read-only for LGU staff.');
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final response = await _apiClient.get(ApiEndpoints.lguEmergencyContacts);
    if (response.statusCode == 200 && response.data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(response.data['data'] as List);
    }
    throw Exception('Unable to load emergency contacts.');
  }

  /// Add a database-backed emergency contact.
  Future<bool> createEmergencyContact(Map<String, dynamic> data) async {
    final response =
        await _apiClient.post(ApiEndpoints.lguEmergencyContacts, data: data);
    _map(response);
    return true;
  }

  Future<bool> updateEmergencyContact(
      String id, Map<String, dynamic> data) async {
    _map(
        await _apiClient.put(ApiEndpoints.lguEmergencyContact(id), data: data));
    return true;
  }

  Future<bool> setEmergencyContactActive(String id, bool isActive) async {
    _map(await _apiClient.patch(ApiEndpoints.lguEmergencyContactStatus(id),
        data: {'is_active': isActive}));
    return true;
  }

  Future<bool> verifyEmergencyContact(String id) async {
    _map(await _apiClient.patch(ApiEndpoints.lguVerifyEmergencyContact(id)));
    return true;
  }

  Future<bool> archiveEmergencyContact(String id) async {
    _map(await _apiClient.delete(ApiEndpoints.lguEmergencyContact(id)));
    return true;
  }

  Map<String, dynamic> _map(dynamic response) {
    if (response.statusCode == null ||
        response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.data is! Map ||
        response.data['status'] != 'success') {
      throw StateError(response.data is Map
          ? response.data['message']?.toString() ?? 'Request failed.'
          : 'Request failed.');
    }
    final data = response.data['data'];
    if (data == null) return <String, dynamic>{};
    if (data is! Map) throw const FormatException('Invalid API response.');
    return Map<String, dynamic>.from(data);
  }

  List<Map<String, dynamic>> _list(dynamic response) {
    if (response.statusCode == null ||
        response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.data is! Map ||
        response.data['status'] != 'success') {
      throw StateError('Request failed.');
    }
    final data = response.data['data'];
    if (data is! List) throw const FormatException('Invalid API response.');
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
