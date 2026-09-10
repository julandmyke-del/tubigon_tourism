import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../database/database_helper.dart';
import '../../authentication/auth_provider.dart';

class WasteReportRepository {
  WasteReportRepository({required this.apiClient, required this.ref});

  final ApiClient apiClient;
  final Ref ref;
  final dbHelper = DatabaseHelper.instance;

  String? get _userId => ref.read(authProvider).userId;
  static const _categoryCacheKey = 'waste_categories_public_cache_v1';

  Future<List<WasteCategoryOption>> getCategories() async {
    try {
      final response = await apiClient.get(ApiEndpoints.wasteCategories);
      final rows = response.data['data'];
      if (response.statusCode != 200 || rows is! List) {
        throw const FormatException('Invalid waste-category response.');
      }
      final categories = rows
          .whereType<Map>()
          .map((row) =>
              WasteCategoryOption.fromJson(Map<String, dynamic>.from(row)))
          .where((item) => item.id.isNotEmpty && item.slug.isNotEmpty)
          .toList(growable: false);
      await LocalStorageService.instance.setString(_categoryCacheKey,
          jsonEncode(categories.map((item) => item.toJson()).toList()));
      return categories;
    } catch (_) {
      final cached = LocalStorageService.instance.getString(_categoryCacheKey);
      if (cached == null || cached.isEmpty) rethrow;
      return (jsonDecode(cached) as List<dynamic>)
          .whereType<Map>()
          .map((row) =>
              WasteCategoryOption.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
  }

  /// Submit a waste report. Handles offline caching and conditional image uploads.
  Future<bool> submitReport({
    required String categoryId,
    required String categorySlug,
    required String severity,
    required String description,
    required double? latitude,
    required double? longitude,
    required String? locationText,
    required String? barangay,
    required String? resolvedAddress,
    required String? geocodingSource,
    required List<XFile> photos,
    required XFile? video,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('Must be logged in to submit a report.');
    }

    final reportId = const Uuid().v4();
    final localImagePaths = photos.map((photo) => photo.path).toList();

    if (latitude == null || longitude == null) {
      throw Exception(
          'Select a valid location inside Tubigon before submitting.');
    }

    if (!DatabaseHelper.isSupported) {
      return _submitRemote(
        reportId: reportId,
        categoryId: categoryId,
        categorySlug: categorySlug,
        severity: severity,
        description: description,
        latitude: latitude,
        longitude: longitude,
        locationText: locationText,
        barangay: barangay,
        resolvedAddress: resolvedAddress,
        geocodingSource: geocodingSource,
        photos: photos,
        video: video,
      );
    }

    final localReport = {
      'id': reportId,
      'user_id': userId,
      'category': categorySlug,
      'category_id': categoryId,
      'severity': severity,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'location_description': locationText,
      'barangay': barangay,
      'resolved_address': resolvedAddress,
      'geocoding_source': geocodingSource,
      'images': jsonEncode(localImagePaths),
      'video_path': video?.path,
      'media': jsonEncode(<Map<String, dynamic>>[]),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'dirty': 1,
      'sync_status': 'pending_insert',
      'pending_delete': 0,
    };

    // 1. Cache in SQLite
    await dbHelper.insert('waste_reports', localReport);

    // 2. Attempt direct API submission
    if (SyncService.instance.isOnline) {
      try {
        final response = await apiClient.post(
          ApiEndpoints.wasteReports,
          data: await _submissionData({
            'category_id': categoryId,
            'category_slug': categorySlug,
            'category': categorySlug,
            'severity': severity,
            'description': description,
            'location_description': locationText,
            'barangay': barangay,
            'resolved_address': resolvedAddress,
            'geocoding_source': geocodingSource,
            'latitude': latitude,
            'longitude': longitude,
            'client_submission_id': reportId,
          }, photos, video),
        );

        if ((response.statusCode == 200 || response.statusCode == 201) &&
            response.data['status'] == 'success') {
          final remote =
              Map<String, dynamic>.from(response.data['data'] as Map);
          await dbHelper
              .delete('waste_reports', where: 'id = ?', whereArgs: [reportId]);
          await dbHelper.insert('waste_reports', {
            'id': remote['id'].toString(),
            'user_id': remote['user_id']?.toString() ?? userId,
            'category': remote['category']?.toString() ?? categorySlug,
            'category_id': remote['category_id']?.toString() ?? categoryId,
            'severity': remote['severity']?.toString() ?? severity,
            'description': remote['description']?.toString() ?? description,
            'location_description':
                remote['location_description']?.toString() ?? locationText,
            'barangay': remote['barangay']?.toString() ?? barangay,
            'resolved_address':
                remote['resolved_address']?.toString() ?? resolvedAddress,
            'geocoding_source':
                remote['geocoding_source']?.toString() ?? geocodingSource,
            'latitude': (remote['latitude'] as num?)?.toDouble() ?? latitude,
            'longitude': (remote['longitude'] as num?)?.toDouble() ?? longitude,
            'images': jsonEncode(
                remote['images'] is List ? remote['images'] : <String>[]),
            'video_path': null,
            'media': jsonEncode(
                remote['media'] is List ? remote['media'] : <Object>[]),
            'status': remote['status']?.toString() ?? 'pending',
            'created_at': remote['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'updated_at': remote['updated_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'sync_status': 'synced',
            'dirty': 0,
            'pending_delete': 0,
          });
          return true;
        } else {
          throw Exception('The report could not be accepted by the server.');
        }
      } catch (e) {
        debugPrint('Direct waste report sync failed, cached offline: $e');
        if (e is NetworkException) return false;
        await dbHelper
            .delete('waste_reports', where: 'id = ?', whereArgs: [reportId]);
        rethrow;
      }
    }
    return false;
  }

  Future<bool> _submitRemote({
    required String reportId,
    required String categoryId,
    required String categorySlug,
    required String severity,
    required String description,
    required double latitude,
    required double longitude,
    required String? locationText,
    required String? barangay,
    required String? resolvedAddress,
    required String? geocodingSource,
    required List<XFile> photos,
    required XFile? video,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.wasteReports,
      data: await _submissionData({
        'category_id': categoryId,
        'category_slug': categorySlug,
        'category': categorySlug,
        'severity': severity,
        'description': description,
        'location_description': locationText,
        'barangay': barangay,
        'resolved_address': resolvedAddress,
        'geocoding_source': geocodingSource,
        'latitude': latitude,
        'longitude': longitude,
        'client_submission_id': reportId,
      }, photos, video),
    );
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        response.data['status'] != 'success') {
      throw Exception('Unable to submit the report. Please try again.');
    }
    return true;
  }

  Future<Object> _submissionData(
      Map<String, dynamic> fields, List<XFile> photos, XFile? video) async {
    if (photos.isEmpty && video == null) return fields;
    final photoFiles = <MultipartFile>[];
    for (final photo in photos) {
      photoFiles.add(MultipartFile.fromBytes(await photo.readAsBytes(),
          filename: photo.name));
    }
    return FormData.fromMap({
      ...fields,
      if (photoFiles.isNotEmpty) 'photos': photoFiles,
      if (video != null)
        'video': MultipartFile.fromBytes(await video.readAsBytes(),
            filename: video.name),
    });
  }

  Future<List<WasteReportRecord>> getMyReports() async {
    final userId = _userId;
    if (userId == null) return const [];
    try {
      final response = await apiClient.get(ApiEndpoints.wasteReports);
      final rows = response.data['data'];
      if (response.statusCode != 200 || rows is! List) {
        throw const FormatException('Invalid waste report response.');
      }
      final reports = rows
          .whereType<Map>()
          .map((row) =>
              WasteReportRecord.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      if (DatabaseHelper.isSupported) {
        for (final report in reports) {
          await dbHelper.insert('waste_reports', report.toCacheRow(userId));
        }
      }
      return reports;
    } catch (_) {
      if (!DatabaseHelper.isSupported) rethrow;
      final rows = await dbHelper.query(
        'waste_reports',
        where: 'user_id = ? AND pending_delete = 0',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      return rows.map(WasteReportRecord.fromJson).toList(growable: false);
    }
  }
}

class WasteReportRecord {
  const WasteReportRecord({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.locationDescription,
    this.barangay,
    this.latitude,
    this.longitude,
    this.images = const [],
    this.notes,
    this.history = const [],
    this.severity = 'moderate',
    this.resolvedAddress,
    this.resolutionSummary,
    this.media = const [],
    this.lastSyncedAt,
  });

  final String id;
  final String category;
  final String description;
  final String status;
  final DateTime? createdAt;
  final String? locationDescription;
  final String? barangay;
  final double? latitude;
  final double? longitude;
  final List<String> images;
  final String? notes;
  final List<Map<String, dynamic>> history;
  final String severity;
  final String? resolvedAddress;
  final String? resolutionSummary;
  final List<Map<String, dynamic>> media;
  final DateTime? lastSyncedAt;

  String get reference =>
      'WR-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';

  factory WasteReportRecord.fromJson(Map<String, dynamic> json) {
    List<String> images = const [];
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages.map((item) => item.toString()).toList(growable: false);
    } else if (rawImages is String && rawImages.isNotEmpty) {
      final parsed = jsonDecode(rawImages);
      if (parsed is List) {
        images = parsed.map((item) => item.toString()).toList(growable: false);
      }
    }
    final rawHistory = json['history'];
    final rawMedia = json['media'];
    return WasteReportRecord(
      id: json['id'].toString(),
      category: json['category']?.toString() ?? 'other',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'submitted',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      locationDescription: json['location_description']?.toString(),
      barangay: json['barangay']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      images: images,
      notes: json['lgu_notes']?.toString(),
      history: rawHistory is List
          ? rawHistory
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const [],
      severity: json['severity']?.toString() ?? 'moderate',
      resolvedAddress: json['resolved_address']?.toString(),
      resolutionSummary: json['resolution_summary']?.toString(),
      media: rawMedia is List
          ? rawMedia
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const [],
      lastSyncedAt: DateTime.tryParse(json['last_synced']?.toString() ??
          json['updated_at']?.toString() ??
          ''),
    );
  }

  Map<String, dynamic> toCacheRow(String userId) => {
        'id': id,
        'user_id': userId,
        'category': category,
        'description': description,
        'location_description': locationDescription,
        'barangay': barangay,
        'severity': severity,
        'resolved_address': resolvedAddress,
        'latitude': latitude,
        'longitude': longitude,
        'images': jsonEncode(images),
        'media': jsonEncode(media),
        'status': status,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
        'dirty': 0,
        'pending_delete': 0,
      };
}

class WasteCategoryOption {
  const WasteCategoryOption({
    required this.id,
    required this.slug,
    required this.name,
    this.helperText,
  });

  final String id;
  final String slug;
  final String name;
  final String? helperText;

  factory WasteCategoryOption.fromJson(Map<String, dynamic> json) =>
      WasteCategoryOption(
        id: json['id']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Waste issue',
        helperText: json['helper_text']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'helper_text': helperText,
      };
}

// ─── Riverpod Providers ────────────────────────────────────────────────────────

final wasteReportRepositoryProvider = Provider<WasteReportRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return WasteReportRepository(apiClient: client, ref: ref);
});

final myWasteReportsProvider =
    FutureProvider.autoDispose<List<WasteReportRecord>>((ref) {
  return ref.watch(wasteReportRepositoryProvider).getMyReports();
});

final wasteCategoriesProvider =
    FutureProvider<List<WasteCategoryOption>>((ref) {
  return ref.watch(wasteReportRepositoryProvider).getCategories();
});
