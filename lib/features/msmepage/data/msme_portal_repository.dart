import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

/// Repository for MSME Owner Portal data operations via Laravel REST API backend.
class MsmePortalRepository {
	MsmePortalRepository({required this.apiClient});

	final ApiClient apiClient;

	// ─── Dashboard Stats ────────────────────────────────────────────────────

	Future<Map<String, dynamic>> getDashboardStats() async {
		try {
			final response = await apiClient.get(ApiEndpoints.msmeDashboardStats);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return Map<String, dynamic>.from(response.data['data']);
			}
		} catch (_) {}

		return {
			'totalListings': 8,
			'activeListings': 6,
			'totalReservations': 142,
			'pendingReservations': 9,
			'completedReservations': 118,
			'monthlyVisitors': 3450,
			'averageRating': 4.8,
			'totalRevenue': 184500.0,
			'profileCompletion': 0.85,
		};
	}

	Future<List<Map<String, dynamic>>> getMyListings() async {
		try {
			final response = await apiClient.get(ApiEndpoints.msmePortalListings);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return List<Map<String, dynamic>>.from(response.data['data']);
			}
		} catch (_) {}

		return [
			{
				'id': '1',
				'name': 'Tubigon Loomweaving Crafts Center',
				'category': 'Handicrafts',
				'price': 450.0,
				'capacity': 25,
				'rating': 4.9,
				'status': 'Active',
				'is_featured': true,
				'image': 'https://images.unsplash.com/photo-1544816155-12df9643f363',
				'description': 'Handwoven Raffia Products & Craft Demonstration Workshops.',
				'hours': '8:00 AM - 5:00 PM',
			},
			{
				'id': '2',
				'name': 'Bohol Sea delicacies & Seafood Grill',
				'category': 'Food & Dining',
				'price': 650.0,
				'capacity': 60,
				'rating': 4.7,
				'status': 'Active',
				'is_featured': true,
				'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5',
				'description': 'Freshly cooked local seafood directly sourced from Tubigon waters.',
				'hours': '10:00 AM - 9:00 PM',
			},
			{
				'id': '3',
				'name': 'Tubigon Island Hopping & Boat Charters',
				'category': 'Tour Services',
				'price': 2500.0,
				'capacity': 12,
				'rating': 4.8,
				'status': 'Active',
				'is_featured': false,
				'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
				'description': 'Guided boat trips to Cabingatan & Macaina Sandbar.',
				'hours': '6:00 AM - 4:00 PM',
			},
		];
	}

	Future<void> createListing(Map<String, dynamic> data) async {
		try {
			await apiClient.post(ApiEndpoints.msmePortalListings, data: data);
		} catch (_) {}
	}

	Future<void> updateListing(String id, Map<String, dynamic> data) async {
		try {
			await apiClient.put(ApiEndpoints.msmePortalListingById(id), data: data);
		} catch (_) {}
	}

	Future<void> deleteListing(String id) async {
		try {
			await apiClient.delete(ApiEndpoints.msmePortalListingById(id));
		} catch (_) {}
	}

	Future<List<Map<String, dynamic>>> getReservations({String? statusFilter}) async {
		try {
			final response = await apiClient.get(
				ApiEndpoints.msmePortalReservations,
				queryParameters: {'status': statusFilter},
			);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return List<Map<String, dynamic>>.from(response.data['data']);
			}
		} catch (_) {}

		final all = [
			{
				'id': 'RES-2026-081',
				'guest_name': 'Maria Santos',
				'listing_name': 'Tubigon Loomweaving Crafts Center',
				'date': '2026-08-10',
				'time': '10:00 AM',
				'guests': 4,
				'total_amount': 1800.0,
				'status': 'Pending',
			},
			{
				'id': 'RES-2026-079',
				'guest_name': 'John Doe',
				'listing_name': 'Bohol Sea delicacies & Seafood Grill',
				'date': '2026-08-08',
				'time': '12:30 PM',
				'guests': 2,
				'total_amount': 1300.0,
				'status': 'Confirmed',
			},
			{
				'id': 'RES-2026-075',
				'guest_name': 'Elena Rostova',
				'listing_name': 'Tubigon Island Hopping Boat',
				'date': '2026-08-05',
				'time': '07:00 AM',
				'guests': 6,
				'total_amount': 5000.0,
				'status': 'Completed',
			},
		];

		if (statusFilter != null && statusFilter != 'All') {
			return all.where((r) => r['status'].toString().toLowerCase() == statusFilter.toLowerCase()).toList();
		}
		return all;
	}

	Future<void> updateReservationStatus(String id, String status) async {
		try {
			await apiClient.put(
				ApiEndpoints.msmePortalUpdateReservationStatus(id),
				data: {'status': status},
			);
		} catch (_) {}
	}

	Future<List<Map<String, dynamic>>> getReviews() async {
		try {
			final response = await apiClient.get(ApiEndpoints.msmePortalReviews);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return List<Map<String, dynamic>>.from(response.data['data']);
			}
		} catch (_) {}

		return [
			{
				'id': 'REV-01',
				'reviewer': 'Carlos Gomez',
				'listing': 'Tubigon Loomweaving Crafts Center',
				'rating': 5.0,
				'comment': 'Authentic Boholano craftwork! Watching the weavers live was impressive.',
				'date': '2026-08-01',
				'reply': 'Thank you Carlos! We take great pride in preserving Tubigon loomweaving heritage.',
			},
			{
				'id': 'REV-02',
				'reviewer': 'Sarah Jenkins',
				'listing': 'Bohol Sea delicacies & Seafood Grill',
				'rating': 4.5,
				'comment': 'Fresh seafood right by the harbor. Amazing grilled squid.',
				'date': '2026-07-28',
				'reply': null,
			},
		];
	}

	Future<Map<String, dynamic>> getReviewStats() async {
		try {
			final response = await apiClient.get(ApiEndpoints.msmePortalReviewStats);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return Map<String, dynamic>.from(response.data['data']);
			}
		} catch (_) {}

		return {
			'averageRating': 4.8,
			'totalReviews': 46,
			'fiveStar': 36,
			'fourStar': 8,
			'threeStar': 2,
			'twoStar': 0,
			'oneStar': 0,
		};
	}

	Future<Map<String, dynamic>> getAnalytics() async {
		try {
			final response = await apiClient.get(ApiEndpoints.msmePortalAnalytics);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return Map<String, dynamic>.from(response.data['data']);
			}
		} catch (_) {}

		return {
			'visitorTrend': [320, 450, 510, 680, 890, 1100, 1250, 1420],
			'revenueTrend': [12000, 18500, 24000, 31000, 42000, 56000, 68000, 84500],
			'popularListings': [
				{'name': 'Tubigon Loomweaving Crafts Center', 'bookings': 68},
				{'name': 'Bohol Sea delicacies & Seafood Grill', 'bookings': 52},
				{'name': 'Tubigon Island Hopping & Boat Charters', 'bookings': 22},
			],
		};
	}

	Future<List<Map<String, dynamic>>> getNotifications() async {
		try {
			final response = await apiClient.get(ApiEndpoints.msmePortalNotifications);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return List<Map<String, dynamic>>.from(response.data['data']);
			}
		} catch (_) {}

		return [
			{
				'id': '1',
				'title': 'New Reservation Received',
				'body': 'Maria Santos booked 4 spots for Loomweaving Workshop.',
				'time': '10 mins ago',
				'is_read': false,
				'type': 'reservation',
			},
			{
				'id': '2',
				'title': 'New 5-Star Review',
				'body': 'Carlos Gomez left a glowing review for your business.',
				'time': '2 hours ago',
				'is_read': true,
				'type': 'review',
			},
			{
				'id': '3',
				'title': 'LGU Verification Approved',
				'body': 'Your MSME business license was verified by Tubigon LGU.',
				'time': '1 day ago',
				'is_read': true,
				'type': 'system',
			},
		];
	}

	Future<Map<String, dynamic>> getProfile() async {
		try {
			final response = await apiClient.get(ApiEndpoints.msmePortalProfile);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return Map<String, dynamic>.from(response.data['data']);
			}
		} catch (_) {}

		return {
			'business_name': 'Tubigon Crafts & Loomweaving Guild',
			'owner_name': 'Lourdes Tan',
			'category': 'Handicrafts',
			'email': 'lourdes@tubigoncrafts.ph',
			'phone': '+63 917 555 3821',
			'address': 'Poblacion, Tubigon, Bohol, Philippines',
			'tagline': 'Authentic Loomweaving & Local Bohol Handicrafts',
			'hours': '8:00 AM - 5:00 PM (Mon-Sat)',
			'is_verified': true,
			'description': 'Pioneering raffia loomweaving in Bohol. We offer handmade bags, hats, mats, and tourist craft workshops.',
		};
	}

	Future<void> updateProfile(Map<String, dynamic> profileData) async {
		try {
			await apiClient.put(ApiEndpoints.msmePortalProfile, data: profileData);
		} catch (_) {}
	}

	Future<String> uploadImage(String fileName, List<int> fileBytes) async {
		try {
			final formData = FormData.fromMap({
				'image': MultipartFile.fromBytes(fileBytes, filename: fileName),
			});

			final response = await apiClient.post(ApiEndpoints.uploadImage, data: formData);
			if (response.statusCode == 200 && response.data['status'] == 'success') {
				return response.data['data']['url'] as String;
			}
		} catch (_) {}
		return 'https://images.unsplash.com/photo-1544816155-12df9643f363';
	}
}

