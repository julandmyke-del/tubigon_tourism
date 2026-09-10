import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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

  Future<Map<String, dynamic>> getActivity({
    String period = 'monthly',
    String? type,
    String? search,
  }) async {
    return _map(await _apiClient.get(
      ApiEndpoints.lguActivity,
      queryParameters: {
        'period': period,
        if (type != null && type != 'all') 'type': type,
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      },
    ));
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
    String? severity,
    String? publicNote,
    String? internalNote,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.lguUpdateWasteStatus(reportId),
      data: {
        'status': status,
        if (remarks != null) 'notes': remarks,
        if (publicNote != null) 'public_note': publicNote,
        if (internalNote != null) 'internal_note': internalNote,
        if (assignedPersonnel != null) 'assigned_personnel': assignedPersonnel,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (priority != null) 'priority': priority,
        if (severity != null) 'severity': severity,
      },
    );
    _map(response);
    return true;
  }

  Future<Map<String, dynamic>> uploadWasteResolutionPhoto(
      String reportId, XFile photo) async {
    return _map(await _apiClient.post(
      ApiEndpoints.wasteResolutionMedia(reportId),
      data: FormData.fromMap({
        'photo': MultipartFile.fromBytes(await photo.readAsBytes(),
            filename: photo.name),
      }),
    ));
  }

  Future<Uint8List> getAuthorizedWasteMedia(String url) async {
    final response = await _apiClient.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  /// Fetch municipal tourism analytics & performance metrics
  Future<Map<String, dynamic>> getAnalytics(
    String period, {
    String? from,
    String? to,
  }) async {
    return _map(await _apiClient.get(
      ApiEndpoints.lguAnalytics,
      queryParameters: {
        'period': period,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    ));
  }

  /// Fetch generated municipal report data (daily, weekly, monthly, yearly)
  Future<Map<String, dynamic>> getReports(
    String period, {
    String category = 'tourism_operations',
    String? from,
    String? to,
  }) async {
    return _map(await _apiClient.get(
      ApiEndpoints.lguReports,
      queryParameters: {
        'period': period,
        'category': category,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    ));
  }

  /// Fetch all waste reports for municipal monitoring
  Future<List<Map<String, dynamic>>> getWasteReports() async {
    final reports = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = await _apiClient.get(ApiEndpoints.wasteReports,
          queryParameters: {'page': page, 'per_page': 100});
      reports.addAll(_list(response));
      final meta = response.data['meta'];
      lastPage = meta is Map
          ? int.tryParse(meta['last_page']?.toString() ?? '') ?? page
          : page;
      page++;
    } while (page <= lastPage);
    return reports;
  }

  Future<Map<String, dynamic>> getWasteReport(String id) async =>
      _map(await _apiClient.get(ApiEndpoints.wasteReportById(id)));

  Future<List<Map<String, dynamic>>> getMsmes({String? status}) async => _list(
        await _apiClient.get(ApiEndpoints.lguMsmes,
            queryParameters: {if (status != null) 'status': status}),
      );

  Future<Map<String, dynamic>> getMsme(String id) async =>
      _map(await _apiClient.get(ApiEndpoints.lguMsme(id)));

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
      _list(await _apiClient.get(ApiEndpoints.lguAnnouncements));

  Future<List<Map<String, dynamic>>> getEcoTips() async =>
      _list(await _apiClient.get(ApiEndpoints.lguEcoTips));

  Future<void> saveEcoTip(Map<String, dynamic> data, {String? id}) async {
    final response = id == null
        ? await _apiClient.post(ApiEndpoints.lguEcoTips, data: data)
        : await _apiClient.put(ApiEndpoints.lguEcoTip(id), data: data);
    _map(response);
  }

  Future<void> archiveEcoTip(String id) async {
    final response = await _apiClient.delete(ApiEndpoints.lguEcoTip(id));
    if (response.statusCode == null || response.statusCode! >= 300) {
      throw StateError('Unable to archive the eco tip.');
    }
  }

  Future<List<Map<String, dynamic>>> getFerrySchedules() async =>
      _list(await _apiClient.get(ApiEndpoints.lguFerrySchedules));

  Future<Map<String, dynamic>> getFerryCatalogs() async =>
      _map(await _apiClient.get(ApiEndpoints.ferryCatalogs));

  Future<void> createFerryPort(Map<String, dynamic> data) async {
    _map(await _apiClient.post(ApiEndpoints.lguFerryPorts, data: data));
  }

  Future<void> updateFerryPort(String id, Map<String, dynamic> data) async {
    _map(await _apiClient.put(ApiEndpoints.lguFerryPort(id), data: data));
  }

  Future<void> createFerryRoute(Map<String, dynamic> data) async {
    _map(await _apiClient.post(ApiEndpoints.lguFerryRoutes, data: data));
  }

  Future<void> updateFerryRoute(String id, Map<String, dynamic> data) async {
    _map(await _apiClient.put(ApiEndpoints.lguFerryRoute(id), data: data));
  }

  Future<void> saveFerrySchedule(Map<String, dynamic> data,
      {String? id}) async {
    final response = id == null
        ? await _apiClient.post(ApiEndpoints.lguFerrySchedules, data: data)
        : await _apiClient.put(ApiEndpoints.lguFerrySchedule(id), data: data);
    _map(response);
  }

  Future<void> archiveFerrySchedule(String id) async {
    final response = await _apiClient.delete(ApiEndpoints.lguFerrySchedule(id));
    if (response.statusCode == null || response.statusCode! >= 300) {
      throw StateError('Unable to archive the ferry schedule.');
    }
  }

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

  Future<bool> setEmergencyContactVerification(String id, String status) async {
    _map(await _apiClient.patch(
      ApiEndpoints.lguEmergencyContactVerification(id),
      data: {'verification_status': status},
    ));
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
