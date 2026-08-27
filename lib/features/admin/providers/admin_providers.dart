import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminRepository(apiClient: apiClient);
});

final adminDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getDashboardStats();
});

final adminUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getUsers();
});

final adminRolesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getRoles();
});

final adminMsmesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getMsmes();
});

final adminSpotsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getTouristSpots();
});

final adminCategoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getCategories();
});

final adminFerryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getFerrySchedules();
});

final adminEmergencyProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getEmergencyContacts();
});

final adminEcoTipsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getEcoTips();
});

final adminReservationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllReservations();
});

final adminReservationStatusesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getReservationStatuses();
});

final adminReviewsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllReviews();
});

final adminWasteReportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllWasteReports();
});

final adminAnnouncementsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAnnouncements();
});

final adminSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getSystemSettings();
});

final adminActivityLogsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getActivityLogs();
});
