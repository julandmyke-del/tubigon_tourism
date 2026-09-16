import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../authentication/auth_provider.dart';
import '../data/tourism_partner_repository.dart';

// ─── Repository ──────────────────────────────────────────────────────────────

final tourismPartnerRepositoryProvider =
    Provider<TourismPartnerRepository>((ref) {
  ref.watch(
      authProvider.select((auth) => (auth.isLoggedIn, auth.userId, auth.role)));
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

final currentPartnerAssignmentProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.watch(tourismPartnerRepositoryProvider).getCurrentAssignment();
});

final partnerRecentActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(tourismPartnerRepositoryProvider).getRecentActivity();
});

// ─── Reservations ────────────────────────────────────────────────────────────

final partnerReservationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, statusFilter) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getReservations(statusFilter: statusFilter);
});

class PartnerReservationQuery {
  const PartnerReservationQuery({
    this.status,
    this.search,
    this.scope,
    this.from,
    this.to,
    this.sort = 'visit_asc',
  });

  final String? status;
  final String? search;
  final String? scope;
  final String? from;
  final String? to;
  final String sort;

  @override
  bool operator ==(Object other) =>
      other is PartnerReservationQuery &&
      status == other.status &&
      search == other.search &&
      scope == other.scope &&
      from == other.from &&
      to == other.to &&
      sort == other.sort;

  @override
  int get hashCode => Object.hash(status, search, scope, from, to, sort);
}

final partnerReservationQueueProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, PartnerReservationQuery>((ref, query) {
  return ref.watch(tourismPartnerRepositoryProvider).getReservationQueue(
        statusFilter: query.status,
        search: query.search,
        scope: query.scope,
        from: query.from,
        to: query.to,
        sort: query.sort,
      );
});

// ─── Notifications ───────────────────────────────────────────────────────────

final partnerNotificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getNotifications();
});

final partnerFilteredNotificationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, filter) async {
  return ref.watch(tourismPartnerRepositoryProvider).getNotifications(
        filter: filter,
      );
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

final partnerAnalyticsPeriodProvider =
    StateProvider<String>((ref) => '30_days');

final partnerAnalyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getAnalytics(period: ref.watch(partnerAnalyticsPeriodProvider));
});

// ─── Profile ─────────────────────────────────────────────────────────────────

final partnerProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(tourismPartnerRepositoryProvider);
  return repo.getProfile();
});
