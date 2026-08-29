import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/tourism_partner_repository.dart';

// ─── Repository ──────────────────────────────────────────────────────────────

final tourismPartnerRepositoryProvider =
    Provider<TourismPartnerRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TourismPartnerRepository(apiClient: apiClient);
});

// ─── Dashboard ───────────────────────────────────────────────────────────────

final partnerDashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getDashboardStats();
});

// ─── Listings ────────────────────────────────────────────────────────────────

final partnerListingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getMyListings();
});

final partnerManagedDestinationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(tourismPartnerRepositoryProvider).getManagedDestinations();
});

// ─── Reservations ────────────────────────────────────────────────────────────

final partnerReservationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, statusFilter) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getReservations(statusFilter: statusFilter);
});

// ─── Notifications ───────────────────────────────────────────────────────────

final partnerNotificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getNotifications();
});

// ─── Reviews ─────────────────────────────────────────────────────────────────

final partnerReviewsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getListingReviews();
});

final partnerReviewStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getReviewStats();
});

// ─── Analytics ───────────────────────────────────────────────────────────────

final partnerAnalyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getAnalytics();
});

// ─── Profile ─────────────────────────────────────────────────────────────────

final partnerProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getProfile();
});
