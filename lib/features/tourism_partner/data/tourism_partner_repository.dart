import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Repository for Tourism Partner data operations via Laravel REST API backend.
class TourismPartnerRepository {
  TourismPartnerRepository({required this.apiClient});

  final ApiClient apiClient;

  // ─── Dashboard Stats ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await apiClient.get('/partner/dashboard-stats');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception('Failed to fetch dashboard stats');
    } catch (e) {
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  // ─── My Listings ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyListings() async {
    try {
      final response = await apiClient.get('/partner/listings');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch listings: $e');
    }
  }

  Future<Map<String, dynamic>> getListingById(String listingId) async {
    try {
      final response = await apiClient.get('/partner/listings/$listingId');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception('Listing not found');
    } catch (e) {
      throw Exception('Failed to fetch listing: $e');
    }
  }

  Future<void> createListing(Map<String, dynamic> listingData) async {
    try {
      await apiClient.post('/partner/listings', data: listingData);
    } catch (e) {
      throw Exception('Failed to create listing: $e');
    }
  }

  Future<void> updateListing(String listingId, Map<String, dynamic> listingData) async {
    try {
      await apiClient.put('/partner/listings/$listingId', data: listingData);
    } catch (e) {
      throw Exception('Failed to update listing: $e');
    }
  }

  Future<void> deleteListing(String listingId) async {
    try {
      await apiClient.delete('/partner/listings/$listingId');
    } catch (e) {
      throw Exception('Failed to delete listing: $e');
    }
  }

  // ─── Reservations ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getReservations({String? statusFilter}) async {
    try {
      final response = await apiClient.get(
        '/partner/reservations',
        queryParameters: {'status_filter': statusFilter},
      );
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch reservations: $e');
    }
  }

  Future<Map<String, dynamic>> getReservationById(String reservationId) async {
    try {
      final response = await apiClient.get('/reservations/$reservationId');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception('Reservation not found');
    } catch (e) {
      throw Exception('Failed to fetch reservation: $e');
    }
  }

  Future<void> updateReservationStatus(String reservationId, String statusName) async {
    try {
      await apiClient.put(
        '/partner/reservations/$reservationId/status',
        data: {'status_name': statusName},
      );
    } catch (e) {
      throw Exception('Failed to update reservation status: $e');
    }
  }

  // ─── Notifications ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await apiClient.get('/partner/notifications');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await apiClient.put('/partner/notifications/$notificationId/read');
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await apiClient.put('/partner/notifications/read-all');
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await apiClient.delete('/partner/notifications/$notificationId');
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  // ─── Reviews ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getListingReviews() async {
    try {
      final response = await apiClient.get('/partner/reviews');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  Future<Map<String, dynamic>> getReviewStats() async {
    try {
      final response = await apiClient.get('/partner/review-stats');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return Map<String, dynamic>.from(response.data['data']);
      }
      return {'averageRating': 0.0, 'totalReviews': 0};
    } catch (e) {
      throw Exception('Failed to fetch review stats: $e');
    }
  }

  // ─── Analytics ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final response = await apiClient.get('/partner/analytics');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception('Failed to fetch analytics');
    } catch (e) {
      throw Exception('Failed to fetch analytics: $e');
    }
  }

  // ─── Profile ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await apiClient.get('/partner/profile');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception('Profile not found');
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    try {
      await apiClient.put('/partner/profile', data: profileData);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await apiClient.put('/partner/password', data: {
        'password': newPassword,
        'password_confirmation': newPassword,
      });
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  // ─── Image Upload ───────────────────────────────────────────────────────

  Future<String> uploadListingImage(String fileName, List<int> fileBytes) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(fileBytes, filename: fileName),
      });

      final response = await apiClient.post('/partner/images/upload', data: formData);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return response.data['data']['url'] as String;
      }
      throw Exception('Image upload failed');
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
