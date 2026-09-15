import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/auth_provider.dart';
import '../repositories/lgu_repository.dart';

export '../repositories/lgu_repository.dart'
    show lguRepositoryProvider, LguRepository;

class LguDateRange {
  const LguDateRange(this.from, this.to);

  final String from;
  final String to;
}

final lguDashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(lguRepositoryProvider);
  return repository.getDashboardStats();
});

final lguAnalyticsPeriodProvider = StateProvider<String>((ref) => 'monthly');
final lguAnalyticsDateRangeProvider =
    StateProvider<LguDateRange?>((ref) => null);

final lguAnalyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final period = ref.watch(lguAnalyticsPeriodProvider);
  final range = ref.watch(lguAnalyticsDateRangeProvider);
  final repository = ref.watch(lguRepositoryProvider);
  return repository.getAnalytics(period, from: range?.from, to: range?.to);
});

final lguReportPeriodProvider = StateProvider<String>((ref) => 'monthly');
final lguReportDateRangeProvider = StateProvider<LguDateRange?>((ref) => null);
final lguReportCategoryProvider =
    StateProvider<String>((ref) => 'tourism_operations');

final lguReportsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final period = ref.watch(lguReportPeriodProvider);
  final range = ref.watch(lguReportDateRangeProvider);
  final category = ref.watch(lguReportCategoryProvider);
  final repository = ref.watch(lguRepositoryProvider);
  return repository.getReports(period,
      category: category, from: range?.from, to: range?.to);
});

final lguActivityPeriodProvider = StateProvider<String>((ref) => 'monthly');
final lguActivityTypeProvider = StateProvider<String>((ref) => 'all');
final lguActivitySearchProvider = StateProvider<String>((ref) => '');

final lguActivityProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(lguRepositoryProvider).getActivity(
        period: ref.watch(lguActivityPeriodProvider),
        type: ref.watch(lguActivityTypeProvider),
        search: ref.watch(lguActivitySearchProvider),
      );
});

final lguWasteReportsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(
      authProvider.select((auth) => (auth.isLoggedIn, auth.userId, auth.role)));
  final repository = ref.watch(lguRepositoryProvider);
  return repository.getWasteReports();
});

final lguWasteReportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(lguRepositoryProvider).getWasteReport(id);
});

final lguMsmesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, status) async {
  return ref.watch(lguRepositoryProvider).getMsmes(status: status);
});

final lguMsmeProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(lguRepositoryProvider).getMsme(id);
});

final lguTouristSpotsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(lguRepositoryProvider).getTouristSpots();
});

final lguReservationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(lguRepositoryProvider).getSpotReservations();
});

final lguReservationStatusesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(lguRepositoryProvider).getReservationStatuses();
});

final lguTourismListingsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, status) async {
  return ref.watch(lguRepositoryProvider).getTourismListings(status: status);
});

final announcementsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(lguRepositoryProvider).getAnnouncements();
});

final lguEcoTipsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(lguRepositoryProvider).getEcoTips();
});

final lguFerrySchedulesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(lguRepositoryProvider).getFerrySchedules();
});

final lguFerryCatalogsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(lguRepositoryProvider).getFerryCatalogs();
});
