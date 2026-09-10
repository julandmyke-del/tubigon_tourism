import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminRepository(apiClient: apiClient);
});

final adminDashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getDashboardStats();
});

final adminUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getUsers();
});

final adminUserProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).getUser(userId);
});

final adminRolesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getRoles();
});

final adminMsmesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getMsmes();
});

final adminSpotsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getTouristSpots();
});

final adminCategoriesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getCategories();
});

final adminFerryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getFerrySchedules();
});

final adminEmergencyProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getEmergencyContacts();
});

final adminEcoTipsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getEcoTips();
});

final adminReservationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllReservations();
});

final adminReservationProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, reservationId) {
  return ref.watch(adminRepositoryProvider).getReservation(reservationId);
});

final adminReservationStatusesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getReservationStatuses();
});

final adminReviewsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllReviews();
});

final adminWasteReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllWasteReports();
});

final adminAnnouncementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAnnouncements();
});

final adminSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getSystemSettings();
});

class AdminActivityLogQuery {
  const AdminActivityLogQuery({
    this.page = 1,
    this.role,
    this.action,
    this.dateFrom,
    this.dateTo,
    this.search,
  });
  final int page;
  final String? role;
  final String? action;
  final String? dateFrom;
  final String? dateTo;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is AdminActivityLogQuery &&
      other.page == page &&
      other.role == role &&
      other.action == action &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.search == search;
  @override
  int get hashCode => Object.hash(page, role, action, dateFrom, dateTo, search);
}

final adminActivityLogsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, AdminActivityLogQuery>((ref, query) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getActivityLogs(
    page: query.page,
    role: query.role,
    action: query.action,
    dateFrom: query.dateFrom,
    dateTo: query.dateTo,
    search: query.search,
  );
});
