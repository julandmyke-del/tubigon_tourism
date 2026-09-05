import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/role_application.dart';

class RoleApplicationRepository {
  const RoleApplicationRepository(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> options() async =>
      _map(await _client.get(ApiEndpoints.roleApplicationOptions));

  Future<List<RoleApplication>> mine() async =>
      _list(await _client.get(ApiEndpoints.roleApplications));

  Future<RoleApplication> create(String type) async => _item(
        await _client.post(ApiEndpoints.roleApplications,
            data: {'application_type': type}),
      );

  Future<RoleApplication> get(String id) async =>
      _item(await _client.get(ApiEndpoints.roleApplication(id)));

  Future<RoleApplication> save(String id, Map<String, dynamic> data) async =>
      _item(await _client.put(ApiEndpoints.roleApplication(id), data: data));

  Future<RoleApplication> submit(String id, Map<String, dynamic> data) async =>
      _item(await _client.post(ApiEndpoints.submitRoleApplication(id),
          data: data));

  Future<RoleApplication> withdraw(String id) async =>
      _item(await _client.post(ApiEndpoints.withdrawRoleApplication(id)));

  Future<List<RoleApplication>> lguList(
          {String? type,
          String? status,
          String? search,
          String? dateFrom,
          String? dateTo}) async =>
      _list(
          await _client.get(ApiEndpoints.lguRoleApplications, queryParameters: {
        if (type?.isNotEmpty == true) 'application_type': type,
        if (status?.isNotEmpty == true) 'status': status,
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      }));

  Future<RoleApplication> lguAction(String id, String action,
          {String? notes, Map<String, bool>? checklist}) async =>
      _item(await _client
          .post(ApiEndpoints.lguRoleApplicationAction(id, action), data: {
        if (notes != null) 'notes': notes,
        if (checklist != null) 'checklist': checklist,
      }));

  Future<List<RoleApplication>> adminList(
          {String? type,
          String? status,
          String? search,
          String? dateFrom,
          String? dateTo}) async =>
      _list(
          await _client.get(ApiEndpoints.adminAccessRequests, queryParameters: {
        if (type?.isNotEmpty == true) 'application_type': type,
        if (status?.isNotEmpty == true) 'status': status,
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      }));

  Future<RoleApplication> adminAction(String id, String action,
          {String? notes}) async =>
      _item(await _client.post(
          ApiEndpoints.adminAccessRequestAction(id, action),
          data: {if (notes != null) 'notes': notes}));

  Map<String, dynamic> _map(dynamic response) =>
      Map<String, dynamic>.from(response.data['data'] as Map);

  RoleApplication _item(dynamic response) =>
      RoleApplication.fromJson(_map(response));

  List<RoleApplication> _list(dynamic response) =>
      (response.data['data'] as List? ?? const [])
          .whereType<Map>()
          .map(
              (row) => RoleApplication.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
}
