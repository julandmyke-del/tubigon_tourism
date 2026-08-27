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
    try {
      final response = await _apiClient.get(ApiEndpoints.lguDashboardStats);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Update tourist spot status (Active, Maintenance, Inactive)
  Future<bool> updateSpotStatus(String spotId, String status) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.lguUpdateSpotStatus(spotId),
        data: {'status': status},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Verify, approve, reject, or suspend MSME business registrations
  Future<bool> verifyMsme(
    String msmeId,
    bool isVerified, {
    String? status,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.lguVerifyMsme(msmeId),
        data: {
          'is_verified': isVerified,
          if (status != null) 'status': status,
          if (notes != null) 'notes': notes,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Update environmental waste report status, remarks & assigned team
  Future<bool> updateWasteReportStatus(
    String reportId,
    String status, {
    String? remarks,
    String? assignedPersonnel,
  }) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.lguUpdateWasteStatus(reportId),
        data: {
          'status': status,
          if (remarks != null) 'remarks': remarks,
          if (assignedPersonnel != null)
            'assigned_personnel': assignedPersonnel,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch municipal tourism analytics & performance metrics
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.lguAnalytics);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Fetch generated municipal report data (daily, weekly, monthly, yearly)
  Future<Map<String, dynamic>> getReports(String period) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.lguReports,
        queryParameters: {'period': period},
      );
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Fetch all waste reports for municipal monitoring
  Future<List<Map<String, dynamic>>> getWasteReports() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.wasteReports);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final list = response.data['data'] as List<dynamic>? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Moderate community reviews (publish or flag)
  Future<bool> moderateReview(String reviewId, String status) async {
    try {
      final response = await _apiClient.put(
        '/api/v1/reviews/$reviewId/moderate',
        data: {'status': status},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Post a new municipal announcement
  Future<bool> createAnnouncement(Map<String, dynamic> data) async {
    try {
      final response =
          await _apiClient.post(ApiEndpoints.announcements, data: data);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Add a new eco-tourism tip
  Future<bool> createEcoTip(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.ecoTips, data: data);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
    try {
      final response =
          await _apiClient.post(ApiEndpoints.lguEmergencyContacts, data: data);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateEmergencyContact(
      String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient
          .put(ApiEndpoints.lguEmergencyContact(id), data: data);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setEmergencyContactActive(String id, bool isActive) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.lguEmergencyContactStatus(id),
        data: {'is_active': isActive},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyEmergencyContact(String id) async {
    try {
      final response =
          await _apiClient.patch(ApiEndpoints.lguVerifyEmergencyContact(id));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> archiveEmergencyContact(String id) async {
    try {
      final response =
          await _apiClient.delete(ApiEndpoints.lguEmergencyContact(id));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
