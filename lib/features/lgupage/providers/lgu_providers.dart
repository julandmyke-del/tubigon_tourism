import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/lgu_repository.dart';

export '../repositories/lgu_repository.dart'
    show lguRepositoryProvider, LguRepository;

final lguDashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(lguRepositoryProvider);
  return repository.getDashboardStats();
});

final lguAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(lguRepositoryProvider);
  return repository.getAnalytics();
});

final lguReportPeriodProvider = StateProvider<String>((ref) => 'monthly');

final lguReportsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final period = ref.watch(lguReportPeriodProvider);
  final repository = ref.watch(lguRepositoryProvider);
  return repository.getReports(period);
});

final lguWasteReportsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
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
