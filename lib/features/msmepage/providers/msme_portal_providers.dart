import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/msme_portal_repository.dart';

final msmePortalRepositoryProvider = Provider<MsmePortalRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return MsmePortalRepository(apiClient: client);
});

class MsmeAnalyticsRange {
  const MsmeAnalyticsRange(this.from, this.to);
  final String from;
  final String to;
}

final currentMsmeProvider =
    FutureProvider.autoDispose<CurrentMsmeState>((ref) async {
  return ref.watch(msmePortalRepositoryProvider).getCurrentBusiness();
});

final msmePortalDashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(msmePortalRepositoryProvider);
  final current = await ref.watch(currentMsmeProvider.future);
  if (!current.hasBusiness) {
    return const {
      'business': null,
      'profileCompletion': {'percent': 0, 'items': <String, bool>{}},
      'profile_required': true,
    };
  }
  return repo.getDashboardStats();
});

final msmePortalListingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final current = await ref.watch(currentMsmeProvider.future);
  return current.business == null ? const [] : [current.business!];
});

final msmePortalReservationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, statusFilter) async {
  final repo = ref.watch(msmePortalRepositoryProvider);
  final current = await ref.watch(currentMsmeProvider.future);
  if (!current.hasBusiness) return const [];
  return repo.getReservations(statusFilter: statusFilter);
});

final msmePortalReviewDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(msmePortalRepositoryProvider);
  final current = await ref.watch(currentMsmeProvider.future);
  if (!current.hasBusiness) {
    return const {
      'averageRating': 0.0,
      'reviewCount': 0,
      'ratingDistribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
      'reviews': <Map<String, dynamic>>[],
      'profile_required': true,
    };
  }
  return repo.getReviewData();
});

final msmePortalReviewsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(msmePortalReviewDataProvider.future);
  final rows = data['reviews'] as List? ?? const [];
  return rows.whereType<Map>().map((raw) {
    final row = Map<String, dynamic>.from(raw);
    final user = row['user'];
    return {
      ...row,
      'reviewer': user is Map ? user['name'] : 'Tourist',
      'comment': row['content'],
      'date': row['created_at'],
    };
  }).toList(growable: false);
});

final msmePortalReviewStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(msmePortalReviewDataProvider.future);
  return {
    'averageRating': data['averageRating'] ?? 0,
    'totalReviews': data['reviewCount'] ?? 0,
    'ratingDistribution': data['ratingDistribution'] ?? const {},
  };
});

final msmeAnalyticsPeriodProvider = StateProvider<String>((ref) => '30_days');
final msmeAnalyticsRangeProvider =
    StateProvider<MsmeAnalyticsRange?>((ref) => null);

final msmePortalAnalyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(msmePortalRepositoryProvider);
  final range = ref.watch(msmeAnalyticsRangeProvider);
  final period = ref.watch(msmeAnalyticsPeriodProvider);
  final current = await ref.watch(currentMsmeProvider.future);
  if (!current.hasBusiness) {
    return const {'business': null, 'profile_required': true};
  }
  return repo.getAnalytics(
    period: period,
    from: range?.from,
    to: range?.to,
  );
});

final msmePortalNotificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(msmePortalRepositoryProvider);
  return repo.getNotifications();
});

final msmePortalProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final current = await ref.watch(currentMsmeProvider.future);
  return current.business ?? const {};
});
