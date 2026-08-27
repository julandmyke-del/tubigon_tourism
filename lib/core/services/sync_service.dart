import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../constants/app_constants.dart';
import '../network/api_interceptors.dart';
import '../../database/database_helper.dart';
import 'local_storage_service.dart';

/// Service responsible for managing offline caching sync and connectivity state
/// mapping via the Laravel REST API.
class SyncService {
  SyncService._privateConstructor() {
    _initConnectivityListener();
  }

  static final SyncService instance = SyncService._privateConstructor();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  // Stream controller to notify UI of network changes
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  Dio? _dio;

  Dio get _apiDio {
    if (_dio != null) return _dio!;
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.apiConnectTimeout,
      receiveTimeout: AppConstants.apiReceiveTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));
    _dio!.interceptors.add(AuthInterceptor());
    return _dio!;
  }

  void _initConnectivityListener() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final oldOnline = _isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      _connectionController.add(_isOnline);
      if (_isOnline && !oldOnline) {
        debugPrint(
            '[SyncService] Device came online — flushing pending queue.');
        triggerSyncAll();
      }
    });

    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      _connectionController.add(_isOnline);
    });
  }

  /// Triggers full bidirectional sync across write-creatable user tables.
  Future<void> triggerSyncAll() async {
    if (!_isOnline) {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any((result) => result != ConnectivityResult.none);
    }
    if (!_isOnline || !DatabaseHelper.isSupported) return;
    try {
      await syncTableToRemote('reservations');
      await syncTableToRemote('reviews');
      await syncTableToRemote('favorites');
      await syncTableToRemote('waste_reports');
      debugPrint('[SyncService] Sync cycle complete.');
    } catch (e) {
      debugPrint('[SyncService] Sync queue flush failed: $e');
    }
  }

  /// Pushes dirty SQLite rows to the Laravel API backend.
  Future<void> syncTableToRemote(String tableName) async {
    if (!_isOnline || !DatabaseHelper.isSupported) return;
    final dbHelper = DatabaseHelper.instance;
    final activeUserId = LocalStorageService.instance.getString('auth_user_id');
    if (activeUserId == null || activeUserId.isEmpty) return;

    try {
      // 1. Process pending deletes
      final pendingDeletes = await dbHelper.query(
        tableName,
        where: 'user_id = ? AND pending_delete = 1',
        whereArgs: [activeUserId],
      );
      for (final row in pendingDeletes) {
        final id = row['id'] as String;
        try {
          if (tableName == 'favorites') {
            final response = await _apiDio.post(
              ApiEndpoints.toggleFavorite,
              data: {
                'favoritable_type': row['favoritable_type'],
                'favoritable_id': row['favoritable_id'],
              },
            );
            if (response.data['data']?['is_favorite'] == true) {
              // The remote item was absent before the toggle; undo the accidental add.
              await _apiDio.post(
                ApiEndpoints.toggleFavorite,
                data: {
                  'favoritable_type': row['favoritable_type'],
                  'favoritable_id': row['favoritable_id'],
                },
              );
            }
          } else if (tableName == 'reviews') {
            await _apiDio.delete(ApiEndpoints.reviewById(id));
          } else {
            // Reservations and reports have protected lifecycle APIs and are not deleted by sync.
            continue;
          }
          await dbHelper.delete(tableName, where: 'id = ?', whereArgs: [id]);
        } catch (error) {
          debugPrint(
              '[SyncService] Pending delete retained for $tableName/$id: $error');
        }
      }

      // 2. Process upserts for dirty rows
      final dirtyRows = await dbHelper.query(
        tableName,
        where: 'user_id = ? AND dirty = 1 AND pending_delete = 0',
        whereArgs: [activeUserId],
      );

      if (dirtyRows.isNotEmpty) {
        final cleanRecords = dirtyRows.map((row) {
          final cleanPayload = Map<String, dynamic>.from(row)
            ..remove('sync_status')
            ..remove('dirty')
            ..remove('pending_delete')
            ..remove('last_synced');
          return cleanPayload;
        }).toList();

        final response = await _apiDio.post(
          ApiEndpoints.syncPush,
          data: {
            'table': tableName,
            'records': cleanRecords,
          },
        );

        if (response.statusCode == 200 &&
            (response.data as Map<String, dynamic>?)?['status'] == 'success') {
          for (final row in dirtyRows) {
            final id = row['id'] as String;
            await dbHelper.update(
              tableName,
              {
                'sync_status': 'synced',
                'dirty': 0,
                'last_synced': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[SyncService] Error uploading $tableName: $e');
    }
  }

  /// Pulls latest remote updates from Laravel API and merges into SQLite.
  Future<void> pullAndMergeTable(String tableName) async {
    if (!_isOnline || !DatabaseHelper.isSupported) return;
    final dbHelper = DatabaseHelper.instance;

    try {
      final response = await _apiDio.get(
        ApiEndpoints.syncPull,
        queryParameters: {'table': tableName},
      );

      if (response.statusCode == 200 &&
          (response.data as Map<String, dynamic>?)?['status'] == 'success') {
        final remoteRows =
            (response.data as Map<String, dynamic>)['data'] as List<dynamic>? ??
                [];

        for (final item in remoteRows) {
          final remoteRow = item as Map<String, dynamic>;
          final id = remoteRow['id'].toString();

          final localResult = await dbHelper.query(
            tableName,
            where: 'id = ?',
            whereArgs: [id],
          );

          final cleanRemote = Map<String, dynamic>.from(remoteRow)
            ..['sync_status'] = 'synced'
            ..['dirty'] = 0
            ..['pending_delete'] = 0
            ..['last_synced'] = DateTime.now().toIso8601String();

          if (localResult.isEmpty) {
            await dbHelper.insert(tableName, cleanRemote);
          } else {
            final localRow = localResult.first;
            final localIsDirty = (localRow['dirty'] as int? ?? 0) == 1;
            if (!localIsDirty) {
              await dbHelper.update(
                tableName,
                cleanRemote,
                where: 'id = ?',
                whereArgs: [id],
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SyncService] Error merging $tableName from remote: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectionController.close();
  }
}
