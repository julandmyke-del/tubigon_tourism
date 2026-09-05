import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/role_application_repository.dart';
import '../models/role_application.dart';

final roleApplicationRepositoryProvider =
    Provider((ref) => RoleApplicationRepository(ref.watch(apiClientProvider)));

final roleApplicationOptionsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(roleApplicationRepositoryProvider);
  return repository.options();
});

final myRoleApplicationsProvider =
    FutureProvider.autoDispose<List<RoleApplication>>((ref) async {
  final repository = ref.watch(roleApplicationRepositoryProvider);
  return repository.mine();
});

final roleApplicationProvider =
    FutureProvider.autoDispose.family<RoleApplication, String>((ref, id) async {
  final repository = ref.watch(roleApplicationRepositoryProvider);
  return repository.get(id);
});

class RoleApplicationFilter {
  const RoleApplicationFilter(
      {this.type, this.status, this.search, this.dateFrom, this.dateTo});
  final String? type;
  final String? status;
  final String? search;
  final String? dateFrom;
  final String? dateTo;

  @override
  bool operator ==(Object other) =>
      other is RoleApplicationFilter &&
      other.type == type &&
      other.status == status &&
      other.search == search &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;
  @override
  int get hashCode => Object.hash(type, status, search, dateFrom, dateTo);
}

final lguRoleApplicationsProvider = FutureProvider.autoDispose
    .family<List<RoleApplication>, RoleApplicationFilter>((ref, filter) async {
  final repository = ref.watch(roleApplicationRepositoryProvider);
  return repository.lguList(
      type: filter.type,
      status: filter.status,
      search: filter.search,
      dateFrom: filter.dateFrom,
      dateTo: filter.dateTo);
});

final adminAccessRequestsProvider = FutureProvider.autoDispose
    .family<List<RoleApplication>, RoleApplicationFilter>((ref, filter) async {
  final repository = ref.watch(roleApplicationRepositoryProvider);
  return repository.adminList(
      type: filter.type,
      status: filter.status,
      search: filter.search,
      dateFrom: filter.dateFrom,
      dateTo: filter.dateTo);
});
