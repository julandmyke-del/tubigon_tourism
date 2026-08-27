import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sync_service.dart';
import '../../../database/database_helper.dart';
import '../../authentication/auth_provider.dart';

class WasteReportRepository {
  WasteReportRepository({required this.apiClient, required this.ref});

  final ApiClient apiClient;
  final Ref ref;
  final dbHelper = DatabaseHelper.instance;

  String? get _userId => ref.read(authProvider).userId;

  /// Submit a waste report. Handles offline caching and conditional image uploads.
  Future<bool> submitReport({
    required String category,
    required String description,
    required double? latitude,
    required double? longitude,
    required String? locationText,
    required String? localImagePath,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('Must be logged in to submit a report.');
    }

    final reportId = const Uuid().v4();
    final imageUrl = localImagePath;

    if (latitude == null || longitude == null) {
      throw Exception(
          'Select a valid location inside Tubigon before submitting.');
    }

    if (!DatabaseHelper.isSupported) {
      return _submitRemote(
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
        locationText: locationText,
        imageUrl: imageUrl,
      );
    }

    final localReport = {
      'id': reportId,
      'user_id': userId,
      'category': category,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'location_description': locationText,
      'images': jsonEncode(imageUrl != null ? [imageUrl] : <String>[]),
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
          data: {
            'category': category,
            'description': description,
            'location_description': locationText,
            'latitude': latitude,
            'longitude': longitude,
            if (imageUrl != null) 'images': [imageUrl],
          },
        );

        if (response.statusCode == 201 &&
            response.data['status'] == 'success') {
          final remote =
              Map<String, dynamic>.from(response.data['data'] as Map);
          await dbHelper
              .delete('waste_reports', where: 'id = ?', whereArgs: [reportId]);
          await dbHelper.insert('waste_reports', {
            'id': remote['id'].toString(),
            'user_id': remote['user_id']?.toString() ?? userId,
            'category': remote['category']?.toString() ?? category,
            'description': remote['description']?.toString() ?? description,
            'location_description':
                remote['location_description']?.toString() ?? locationText,
            'latitude': (remote['latitude'] as num?)?.toDouble() ?? latitude,
            'longitude': (remote['longitude'] as num?)?.toDouble() ?? longitude,
            'images': jsonEncode(
                remote['images'] is List ? remote['images'] : <String>[]),
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
        rethrow;
      }
    }
    return false;
  }

  Future<bool> _submitRemote({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required String? locationText,
    required String? imageUrl,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.wasteReports,
      data: {
        'category': category,
        'description': description,
        'location_description': locationText,
        'latitude': latitude,
        'longitude': longitude,
        if (imageUrl != null) 'images': [imageUrl],
      },
    );
    if (response.statusCode != 201 || response.data['status'] != 'success') {
      throw Exception('Unable to submit the report. Please try again.');
    }
    return true;
  }
}

// ─── Riverpod Providers ────────────────────────────────────────────────────────

final wasteReportRepositoryProvider = Provider<WasteReportRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return WasteReportRepository(apiClient: client, ref: ref);
});
