import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/services/local_storage_service.dart';

class ConnectedOperationsRepository {
  ConnectedOperationsRepository(this.client);
  final ApiClient client;
  static const _concernDraftKey = 'concern_submission_draft_v1';

  Future<Map<String, dynamic>> publicOfferings(String spotId) => _cachedMap(
      ApiEndpoints.publicBookingOfferings(spotId), 'offerings_$spotId');

  Future<List<Map<String, dynamic>>> publicGallery(String spotId) =>
      _cachedList(ApiEndpoints.publicSpotGallery(spotId), 'gallery_$spotId');

  Future<List<Map<String, dynamic>>> announcements({bool guest = false}) =>
      _cachedList(
          guest ? ApiEndpoints.publicAnnouncements : ApiEndpoints.announcements,
          'announcements_${guest ? 'public' : 'account'}');

  Future<void> markAnnouncementRead(String id) async {
    await _requireOnline();
    _ensure(await client.put(ApiEndpoints.announcementRead(id)));
  }

  Future<void> dismissAnnouncement(String id) async {
    await _requireOnline();
    _ensure(await client.put(ApiEndpoints.announcementDismiss(id)));
  }

  Future<List<Map<String, dynamic>>> partnerOfferings(String spotId) =>
      _cachedList(
          ApiEndpoints.partnerOfferings(spotId), 'partner_offerings_$spotId');
  Future<void> saveOffering(String spotId, Map<String, dynamic> data,
      {String? id}) async {
    await _requireOnline();
    final response = id == null
        ? await client.post(ApiEndpoints.partnerOfferings(spotId), data: data)
        : await client.put(ApiEndpoints.partnerOffering(spotId, id),
            data: data);
    _ensure(response);
  }

  Future<void> disableOffering(String spotId, String id) async {
    await _requireOnline();
    _ensure(await client.delete(ApiEndpoints.partnerOffering(spotId, id)));
  }

  Future<Map<String, dynamic>> createOfferingReservation(
      Map<String, dynamic> data) async {
    await _requireOnline();
    final response =
        await client.post(ApiEndpoints.offeringReservations, data: data);
    _ensure(response);
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> reservationMessages(String id) =>
      _list(ApiEndpoints.reservationMessages(id));
  Future<void> sendReservationMessage(String id, String message,
      {bool internal = false}) async {
    await _requireOnline();
    _ensure(await client.post(ApiEndpoints.reservationMessages(id),
        data: {'message': message.trim(), 'is_internal': internal}));
  }

  Future<List<Map<String, dynamic>>> partnerGallery(String spotId) =>
      _cachedList(
          ApiEndpoints.partnerSpotGallery(spotId), 'partner_gallery_$spotId');
  Future<void> uploadGalleryImage(String spotId, Uint8List bytes, String name,
      {String? caption,
      String category = 'general',
      String? offeringId,
      bool cover = false}) async {
    await _requireOnline();
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: name),
      if (caption?.trim().isNotEmpty == true) 'caption': caption!.trim(),
      'media_category': category,
      if (offeringId != null) 'booking_offering_id': offeringId,
      'is_cover': cover,
    });
    _ensure(
        await client.post(ApiEndpoints.partnerSpotGallery(spotId), data: form));
  }

  Future<void> updateGalleryMedia(
      String spotId, String mediaId, Map<String, dynamic> data) async {
    await _requireOnline();
    _ensure(await client.put(ApiEndpoints.partnerSpotMedia(spotId, mediaId),
        data: data));
  }

  Future<void> removeGalleryMedia(String spotId, String mediaId) async {
    await updateGalleryMedia(spotId, mediaId, {'is_active': false});
  }

  Future<void> reorderGallery(String spotId, List<String> mediaIds) async {
    await _requireOnline();
    _ensure(await client.put(
        '${ApiEndpoints.partnerSpotGallery(spotId)}/reorder',
        data: {'media_ids': mediaIds}));
  }

  Future<List<Map<String, dynamic>>> concernCategories() =>
      _cachedList(ApiEndpoints.concernCategories, 'concern_categories');

  Future<List<Map<String, dynamic>>> concernRelatedOptions(String type) async {
    final endpoint = switch (type) {
      'reservation' => ApiEndpoints.reservations,
      'ferry_schedule' => ApiEndpoints.ferrySchedules,
      'tourist_spot' => ApiEndpoints.touristSpots,
      'msme' => ApiEndpoints.msmes,
      'waste_report' => ApiEndpoints.myWasteReports,
      'emergency_contact' => ApiEndpoints.emergencyContacts,
      'role_application' => ApiEndpoints.roleApplications,
      _ => throw ArgumentError.value(type, 'type'),
    };
    final response = await client.get(endpoint);
    _ensure(response);
    dynamic rows = response.data['data'];
    if (rows is Map) rows = rows['data'];
    return _maps(rows);
  }

  Future<List<Map<String, dynamic>>> announcementRelatedOptions(
      String type) async {
    final endpoint = switch (type) {
      'tourist_spot' => ApiEndpoints.touristSpots,
      'ferry_schedule' => ApiEndpoints.ferrySchedules,
      'msme' => ApiEndpoints.msmes,
      'eco_tip' => ApiEndpoints.ecoTips,
      'emergency_advisory' => ApiEndpoints.emergencyContacts,
      _ => throw ArgumentError.value(type, 'type'),
    };
    final response = await client.get(endpoint);
    _ensure(response);
    dynamic rows = response.data['data'];
    if (rows is Map) rows = rows['data'];
    return _maps(rows);
  }

  Future<List<Map<String, dynamic>>> concerns({String? role}) async {
    final endpoint = role == 'admin'
        ? ApiEndpoints.adminConcerns
        : role == 'lgu_staff'
            ? ApiEndpoints.lguConcerns
            : ApiEndpoints.concerns;
    final response = await client.get(endpoint);
    _ensure(response);
    final raw = response.data['data'];
    final rows = raw is Map ? raw['data'] : raw;
    return _maps(rows);
  }

  Future<Map<String, dynamic>> concern(String id, {String? role}) async {
    final endpoint = role == 'admin'
        ? ApiEndpoints.adminConcern(id)
        : role == 'lgu_staff'
            ? ApiEndpoints.lguConcern(id)
            : ApiEndpoints.concern(id);
    final response = await client.get(endpoint);
    _ensure(response);
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> createConcern(Map<String, dynamic> data,
      {Uint8List? attachment, String? attachmentName}) async {
    await _requireOnline();
    final payload = attachment == null
        ? data
        : FormData.fromMap({
            ...data,
            'attachment': MultipartFile.fromBytes(
              attachment,
              filename: attachmentName ?? 'concern-evidence.jpg',
            ),
          });
    final response = await client.post(ApiEndpoints.concerns, data: payload);
    _ensure(response);
    await clearConcernDraft();
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Map<String, dynamic>? loadConcernDraft() {
    if (!LocalStorageService.isInitialized) return null;
    final raw = LocalStorageService.instance.getString(_concernDraftKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConcernDraft(Map<String, dynamic> data) async {
    if (!LocalStorageService.isInitialized) return;
    await LocalStorageService.instance.setString(
      _concernDraftKey,
      jsonEncode({...data, 'saved_at': DateTime.now().toIso8601String()}),
    );
  }

  Future<void> clearConcernDraft() async {
    if (!LocalStorageService.isInitialized) return;
    await LocalStorageService.instance.remove(_concernDraftKey);
  }

  Future<void> updateConcern(
      String id, String role, Map<String, dynamic> data) async {
    await _requireOnline();
    final endpoint = role == 'admin'
        ? ApiEndpoints.adminConcern(id)
        : ApiEndpoints.lguConcern(id);
    _ensure(await client.put(endpoint, data: data));
  }

  Future<void> replyConcern(String id, String message,
      {String? role, bool internal = false}) async {
    await _requireOnline();
    final base = role == 'admin'
        ? ApiEndpoints.adminConcern(id)
        : role == 'lgu_staff'
            ? ApiEndpoints.lguConcern(id)
            : ApiEndpoints.concern(id);
    _ensure(await client.post('$base/messages',
        data: {'message': message.trim(), 'is_internal': internal}));
  }

  Future<List<Map<String, dynamic>>> _cachedList(
      String endpoint, String key) async {
    if (!LocalStorageService.isInitialized) return const [];
    if (await checkConnectivity()) {
      try {
        final rows = await _list(endpoint);
        if (LocalStorageService.isInitialized) {
          await LocalStorageService.instance.setString(key, jsonEncode(rows));
        }
        return rows;
      } catch (_) {}
    }
    final raw = LocalStorageService.instance.getString(key);
    return raw == null ? const [] : _maps(jsonDecode(raw));
  }

  Future<Map<String, dynamic>> _cachedMap(String endpoint, String key) async {
    if (!LocalStorageService.isInitialized) {
      return {
        'data': <dynamic>[],
        'meta': <String, dynamic>{},
        'offline': true
      };
    }
    if (await checkConnectivity()) {
      try {
        final response = await client.get(endpoint);
        _ensure(response);
        final value = {
          'data': response.data['data'],
          'meta': response.data['meta'],
          'offline': false
        };
        if (LocalStorageService.isInitialized) {
          await LocalStorageService.instance.setString(key, jsonEncode(value));
        }
        return value;
      } catch (_) {}
    }
    final raw = LocalStorageService.instance.getString(key);
    if (raw == null) {
      return {
        'data': <dynamic>[],
        'meta': <String, dynamic>{},
        'offline': true
      };
    }
    return {
      ...Map<String, dynamic>.from(jsonDecode(raw) as Map),
      'offline': true
    };
  }

  Future<List<Map<String, dynamic>>> _list(String endpoint) async {
    final response = await client.get(endpoint);
    _ensure(response);
    return _maps(response.data['data']);
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
  void _ensure(Response response) {
    if (response.statusCode == null ||
        response.statusCode! >= 300 ||
        response.data is! Map ||
        response.data['status'] != 'success') {
      throw const ServerException(
          message: 'The server could not complete this operation.');
    }
  }

  Future<void> _requireOnline() async {
    if (!await checkConnectivity()) {
      throw const NetworkException(
          message: 'Internet connection is required for this action.');
    }
  }
}

final connectedOperationsRepositoryProvider = Provider(
    (ref) => ConnectedOperationsRepository(ref.watch(apiClientProvider)));
final publicOfferingsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) =>
        ref.watch(connectedOperationsRepositoryProvider).publicOfferings(id));
final publicGalleryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) =>
        ref.watch(connectedOperationsRepositoryProvider).publicGallery(id));
final reservationMessagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) => ref
        .watch(connectedOperationsRepositoryProvider)
        .reservationMessages(id));
final concernCategoriesProvider = FutureProvider((ref) =>
    ref.watch(connectedOperationsRepositoryProvider).concernCategories());
final myConcernsProvider = FutureProvider(
    (ref) => ref.watch(connectedOperationsRepositoryProvider).concerns());
final publicAnnouncementsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, bool>((ref, guest) => ref
        .watch(connectedOperationsRepositoryProvider)
        .announcements(guest: guest));
final partnerOfferingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) =>
        ref.watch(connectedOperationsRepositoryProvider).partnerOfferings(id));
final partnerGalleryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) =>
        ref.watch(connectedOperationsRepositoryProvider).partnerGallery(id));
final staffConcernsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, role) =>
        ref.watch(connectedOperationsRepositoryProvider).concerns(role: role));
