import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/msme_portal_repository.dart';

final msmePortalRepositoryProvider = Provider<MsmePortalRepository>((ref) {
	final client = ref.watch(apiClientProvider);
	return MsmePortalRepository(apiClient: client);
});

final msmePortalDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
	final repo = ref.watch(msmePortalRepositoryProvider);
	return repo.getDashboardStats();
});

final msmePortalListingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
	final repo = ref.watch(msmePortalRepositoryProvider);
	return repo.getMyListings();
});

final msmePortalReservationsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, statusFilter) async {
	final repo = ref.watch(msmePortalRepositoryProvider);
	return repo.getReservations(statusFilter: statusFilter);
});

final msmePortalReviewsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
	final repo = ref.watch(msmePortalRepositoryProvider);
	return repo.getReviews();
});

final msmePortalReviewStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
	final repo = ref.watch(msmePortalRepositoryProvider);
	return repo.getReviewStats();
});

final msmePortalAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
	final repo = ref.watch(msmePortalRepositoryProvider);
	return repo.getAnalytics();
});

final msmePortalNotificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
	final repo = ref.watch(msmePortalRepositoryProvider);
	return repo.getNotifications();
});

final msmePortalProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
	final repo = ref.watch(msmePortalRepositoryProvider);
	return repo.getProfile();
});

