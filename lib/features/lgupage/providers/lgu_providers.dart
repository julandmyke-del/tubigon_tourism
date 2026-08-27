import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/lgu_repository.dart';
import '../../admin/providers/admin_providers.dart';

export '../repositories/lgu_repository.dart' show lguRepositoryProvider, LguRepository;


final lguDashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
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

final lguWasteReportsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(lguRepositoryProvider);
  return repository.getWasteReports();
});

final announcementsListProvider = adminAnnouncementsProvider;
