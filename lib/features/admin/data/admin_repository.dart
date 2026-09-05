import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class AdminRepository {
  AdminRepository({required this.apiClient});

  final ApiClient apiClient;

  // ─── Dashboard Stats & Recent Activities ───────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminDashboardStats);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception('Failed to fetch dashboard stats');
    } catch (e) {
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  // ─── User Management ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminUsers);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch users');
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  Future<Map<String, dynamic>> getUser(String userId) async {
    final response = await apiClient.get(ApiEndpoints.userById(userId));
    if (response.statusCode == 200 && response.data['status'] == 'success') {
      return Map<String, dynamic>.from(response.data['data']);
    }
    throw Exception('Unable to load this user.');
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminRoles);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch roles');
    } catch (e) {
      throw Exception('Failed to fetch roles: $e');
    }
  }

  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      await apiClient.post(ApiEndpoints.adminUsers, data: userData);
      return true;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> userData) async {
    try {
      await apiClient.put(ApiEndpoints.adminUser(userId), data: userData);
      return true;
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<bool> updateUserRole(String userId, String roleId) async {
    try {
      await apiClient.put(
        ApiEndpoints.adminUpdateUserRole(userId),
        data: {'role_id': roleId},
      );
      return true;
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  Future<void> updatePartnerAssignment(
    String userId,
    String? touristSpotId,
  ) async {
    final response = await apiClient.put(
      ApiEndpoints.adminUpdatePartnerAssignment(userId),
      data: {'tourist_spot_id': touristSpotId},
    );
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw Exception('Unable to update the Partner assignment.');
    }
  }

  Future<bool> updateUserActivation(String userId, bool isVerified) async {
    try {
      await apiClient.put(
        ApiEndpoints.adminUpdateUserVerification(userId),
        data: {'is_verified': isVerified},
      );
      return true;
    } catch (e) {
      throw Exception('Failed to update user activation: $e');
    }
  }

  Future<void> updateUserStatus(String userId, bool active) async {
    await apiClient.put(
      ApiEndpoints.adminUpdateUserStatus(userId),
      data: {'active': active},
    );
  }

  Future<void> revokeUserSessions(String userId) async {
    await apiClient.delete(ApiEndpoints.adminRevokeUserSessions(userId));
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await apiClient.delete(ApiEndpoints.adminDeleteUser(userId));
      return true;
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // ─── MSME Management ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMsmes() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminMsmes);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch MSMEs');
    } catch (e) {
      throw Exception('Failed to fetch MSMEs: $e');
    }
  }

  Future<bool> updateMsmeStatus(String msmeId, dynamic isVerified) async {
    try {
      final bool verified = isVerified is bool
          ? isVerified
          : (isVerified == 'approved' ||
              isVerified == 'active' ||
              isVerified == 'verified');
      await apiClient.put(
        ApiEndpoints.adminUpdateMsmeVerification(msmeId),
        data: {'is_verified': verified},
      );
      return true;
    } catch (e) {
      throw Exception('Failed to update MSME verification status: $e');
    }
  }

  Future<bool> deleteMsme(String msmeId) async {
    try {
      await apiClient.delete(ApiEndpoints.adminDeleteMsme(msmeId));
      return true;
    } catch (e) {
      throw Exception('Failed to delete MSME: $e');
    }
  }

  // ─── Tourism Management ────────────────────────────────────────────

  // 1. Tourist Spots
  Future<List<Map<String, dynamic>>> getTouristSpots() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminSpots);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch tourist spots');
    } catch (e) {
      throw Exception('Failed to fetch tourist spots: $e');
    }
  }

  Future<bool> createTouristSpot(Map<String, dynamic> spotData) async {
    await manageTouristSpot(spotData);
    return true;
  }

  Future<void> manageTouristSpot(Map<String, dynamic> spotData,
      {String? id}) async {
    try {
      if (id != null) {
        await apiClient.put(ApiEndpoints.adminUpdateSpot(id), data: spotData);
      } else {
        await apiClient.post(ApiEndpoints.adminCreateSpot, data: spotData);
      }
    } catch (e) {
      throw Exception('Failed to save tourist spot: $e');
    }
  }

  Future<bool> deleteTouristSpot(String id) async {
    try {
      await apiClient.delete(ApiEndpoints.adminDeleteSpot(id));
      return true;
    } catch (e) {
      throw Exception('Failed to delete tourist spot: $e');
    }
  }

  Future<void> updateTouristSpotBooking(
      String id, Map<String, dynamic> configuration) async {
    final response = await apiClient.put(
      ApiEndpoints.adminUpdateSpotBooking(id),
      data: configuration,
    );
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw Exception('Failed to update tourist spot booking configuration.');
    }
  }

  // 2. Categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await apiClient.get(ApiEndpoints.spotCategories);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch categories');
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  Future<void> manageCategory(Map<String, dynamic> categoryData,
      {String? id}) async {
    try {
      if (id != null) {
        await apiClient.put(ApiEndpoints.adminUpdateCategory(id),
            data: categoryData);
      } else {
        await apiClient.post(ApiEndpoints.adminCreateCategory,
            data: categoryData);
      }
    } catch (e) {
      throw Exception('Failed to save category: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await apiClient.delete(ApiEndpoints.adminDeleteCategory(id));
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // 3. Ferry Schedules
  Future<List<Map<String, dynamic>>> getFerrySchedules() async {
    try {
      final response = await apiClient.get(ApiEndpoints.ferrySchedules);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch ferry schedules');
    } catch (e) {
      throw Exception('Failed to fetch ferry schedules: $e');
    }
  }

  Future<void> manageFerrySchedule(Map<String, dynamic> scheduleData,
      {String? id}) async {
    try {
      if (id != null) {
        await apiClient.put(ApiEndpoints.adminFerrySchedule(id),
            data: scheduleData);
      } else {
        await apiClient.post(ApiEndpoints.adminFerrySchedules,
            data: scheduleData);
      }
    } catch (e) {
      throw Exception('Failed to save ferry schedule: $e');
    }
  }

  Future<void> deleteFerrySchedule(String id) async {
    try {
      await apiClient.delete(ApiEndpoints.adminFerrySchedule(id));
    } catch (e) {
      throw Exception('Failed to delete ferry schedule: $e');
    }
  }

  // 4. Emergency Contacts
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminEmergencyContacts);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch emergency contacts');
    } catch (e) {
      throw Exception('Failed to fetch emergency contacts: $e');
    }
  }

  Future<void> manageEmergencyContact(Map<String, dynamic> contactData,
      {String? id}) async {
    try {
      if (id != null) {
        await apiClient.put(ApiEndpoints.adminEmergencyContact(id),
            data: contactData);
      } else {
        await apiClient.post(ApiEndpoints.adminEmergencyContacts,
            data: contactData);
      }
    } catch (e) {
      throw Exception('Failed to save emergency contact: $e');
    }
  }

  Future<void> deleteEmergencyContact(String id) async {
    try {
      await apiClient.delete(ApiEndpoints.adminEmergencyContact(id));
    } catch (e) {
      throw Exception('Failed to delete emergency contact: $e');
    }
  }

  // 5. Eco Tips
  Future<List<Map<String, dynamic>>> getEcoTips() async {
    try {
      final response = await apiClient.get(ApiEndpoints.ecoTips);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch eco tips');
    } catch (e) {
      throw Exception('Failed to fetch eco tips: $e');
    }
  }

  Future<void> manageEcoTip(Map<String, dynamic> ecoTipData,
      {String? id}) async {
    try {
      if (id != null) {
        await apiClient.put(ApiEndpoints.adminEcoTip(id), data: ecoTipData);
      } else {
        await apiClient.post(ApiEndpoints.adminEcoTips, data: ecoTipData);
      }
    } catch (e) {
      throw Exception('Failed to save eco tip: $e');
    }
  }

  Future<void> deleteEcoTip(String id) async {
    try {
      await apiClient.delete(ApiEndpoints.adminEcoTip(id));
    } catch (e) {
      throw Exception('Failed to delete eco tip: $e');
    }
  }

  // ─── Reservations Management ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllReservations() async {
    try {
      final response = await apiClient.get(ApiEndpoints.reservations);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch all reservations');
    } catch (e) {
      throw Exception('Failed to fetch all reservations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getReservationStatuses() async {
    try {
      final response = await apiClient.get(ApiEndpoints.reservationStatuses);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch reservation statuses');
    } catch (e) {
      throw Exception('Failed to fetch reservation statuses: $e');
    }
  }

  Future<Map<String, dynamic>> getReservation(String reservationId) async {
    final response =
        await apiClient.get(ApiEndpoints.reservationById(reservationId));
    if (response.statusCode == 200 && response.data['status'] == 'success') {
      return Map<String, dynamic>.from(response.data['data']);
    }
    throw Exception('Unable to load this reservation.');
  }

  Future<void> updateReservationStatus(
      String reservationId, String statusId) async {
    try {
      await apiClient.put(
        ApiEndpoints.adminUpdateReservationStatus(reservationId),
        data: {'status_id': statusId},
      );
    } catch (e) {
      throw Exception('Failed to update reservation status: $e');
    }
  }

  // ─── Review Management ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllReviews() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminReviews);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch reviews');
    } catch (e) {
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    try {
      await apiClient.delete(ApiEndpoints.reviewById(reviewId));
      return true;
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }

  // ─── Waste Reports ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllWasteReports() async {
    try {
      final response = await apiClient.get(ApiEndpoints.wasteReports);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch waste reports');
    } catch (e) {
      throw Exception('Failed to fetch waste reports: $e');
    }
  }

  Future<bool> updateWasteReportStatus(String reportId, String status) async {
    try {
      await apiClient.put(
        ApiEndpoints.adminUpdateWasteReportStatus(reportId),
        data: {'status': status},
      );
      return true;
    } catch (e) {
      throw Exception('Failed to update waste report status: $e');
    }
  }

  // ─── Announcements ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminAnnouncements);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch announcements');
    } catch (e) {
      throw Exception('Failed to fetch announcements: $e');
    }
  }

  Future<bool> createAnnouncement(Map<String, dynamic> data) async {
    await manageAnnouncement(data);
    return true;
  }

  Future<void> manageAnnouncement(Map<String, dynamic> data,
      {String? id}) async {
    try {
      if (id != null) {
        await apiClient.put(ApiEndpoints.adminAnnouncement(id), data: data);
      } else {
        await apiClient.post(ApiEndpoints.adminAnnouncements, data: data);
      }
    } catch (e) {
      throw Exception('Failed to save announcement: $e');
    }
  }

  Future<bool> deleteAnnouncement(String id) async {
    try {
      await apiClient.delete(ApiEndpoints.adminAnnouncement(id));
      return true;
    } catch (e) {
      throw Exception('Failed to delete announcement: $e');
    }
  }

  // ─── System Settings ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final response = await apiClient.get(ApiEndpoints.systemSettings);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception('Invalid system settings response.');
    } catch (e) {
      throw Exception('Failed to fetch system settings: $e');
    }
  }

  Future<bool> updateSystemSettings(
      Map<String, dynamic> data, String settingsId) async {
    try {
      await apiClient.put(ApiEndpoints.adminSystemSettings(settingsId),
          data: data);
      return true;
    } catch (e) {
      throw Exception('Failed to update system settings: $e');
    }
  }

  // ─── Activity Logs ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getActivityLogs() async {
    try {
      final response = await apiClient.get(ApiEndpoints.adminActivityLogs);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      throw Exception('Failed to fetch activity logs');
    } catch (e) {
      throw Exception('Failed to fetch activity logs: $e');
    }
  }
}
