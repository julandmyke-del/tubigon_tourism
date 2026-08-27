import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../database/database_helper.dart';
import '../../authentication/auth_provider.dart';

class FavoritesRepository {
  FavoritesRepository({required this.apiClient, required this.ref});
  final ApiClient apiClient;
  final Ref ref;
  final dbHelper = DatabaseHelper.instance;

  String? get _userId => ref.read(authProvider).userId;

  static String normalizeType(String value) => switch (value.trim()) {
        'spot' || 'tourist_spot' || 'touristSpot' => 'spot',
        'msme' => 'msme',
        'tourism_listing' || 'tourismListing' => 'tourism_listing',
        'map_location' || 'mapLocation' => 'map_location',
        final value => value,
      };

  Future<bool> isFavorite(String favoritableType, String favoritableId) async {
    favoritableType = normalizeType(favoritableType);
    final userId = _userId;
    if (userId == null) return false;

    if (!DatabaseHelper.isSupported) {
      final favorites = await _fetchRemoteFavorites();
      return favorites.any((item) =>
          item['favoritable_type']?.toString() == favoritableType &&
          item['favoritable_id']?.toString() == favoritableId);
    }

    final local = await dbHelper.query(
      'favorites',
      where:
          'user_id = ? AND favoritable_type = ? AND favoritable_id = ? AND pending_delete = 0',
      whereArgs: [userId, favoritableType, favoritableId],
    );
    return local.isNotEmpty;
  }

  Future<bool> toggleFavorite(
      String favoritableType, String favoritableId) async {
    favoritableType = normalizeType(favoritableType);
    final userId = _userId;
    if (userId == null) throw Exception('Must be logged in to favorite items.');

    final wasFavorite = await isFavorite(favoritableType, favoritableId);

    if (!DatabaseHelper.isSupported) {
      final response = await apiClient.post(
        ApiEndpoints.toggleFavorite,
        data: {
          'favoritable_type': favoritableType,
          'favoritable_id': favoritableId,
        },
      );
      if (response.statusCode != 200 || response.data['status'] != 'success') {
        throw Exception('Unable to update favorites. Please try again.');
      }
      return response.data['data']?['is_favorite'] == true;
    }

    final existing = await dbHelper.query(
      'favorites',
      where: 'user_id = ? AND favoritable_type = ? AND favoritable_id = ?',
      whereArgs: [userId, favoritableType, favoritableId],
    );

    if (existing.isEmpty) {
      final favId = const Uuid().v4();
      final favJson = {
        'id': favId,
        'user_id': userId,
        'favoritable_type': favoritableType,
        'favoritable_id': favoritableId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'dirty': 1,
        'sync_status': 'pending_insert',
        'pending_delete': 0,
      };
      await dbHelper.insert('favorites', favJson);
    } else {
      final favRow = existing.first;
      final favId = favRow['id'] as String;

      if ((favRow['pending_delete'] as int? ?? 0) == 1) {
        await dbHelper.update(
          'favorites',
          {
            'pending_delete': 0,
            'dirty': 1,
            'sync_status': 'pending_update',
          },
          where: 'id = ?',
          whereArgs: [favId],
        );
      } else {
        await dbHelper.update(
          'favorites',
          {
            'pending_delete': 1,
            'dirty': 1,
            'sync_status': 'pending_update',
          },
          where: 'id = ?',
          whereArgs: [favId],
        );
      }
    }

    if (await checkConnectivity()) {
      try {
        final response = await apiClient.post(
          ApiEndpoints.toggleFavorite,
          data: {
            'favoritable_type': favoritableType,
            'favoritable_id': favoritableId,
          },
        );
        final isFavorite = response.data['data']?['is_favorite'] == true;
        final localRows = await dbHelper.query(
          'favorites',
          where: 'user_id = ? AND favoritable_type = ? AND favoritable_id = ?',
          whereArgs: [userId, favoritableType, favoritableId],
        );
        for (final row in localRows) {
          await dbHelper
              .delete('favorites', where: 'id = ?', whereArgs: [row['id']]);
        }
        if (isFavorite) {
          final remote =
              response.data['data']?['favorite'] as Map<String, dynamic>?;
          await dbHelper.insert('favorites', {
            'id': remote?['id']?.toString() ?? const Uuid().v4(),
            'user_id': userId,
            'favoritable_type': favoritableType,
            'favoritable_id': favoritableId,
            'created_at': remote?['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'updated_at': remote?['updated_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'sync_status': 'synced',
            'dirty': 0,
            'pending_delete': 0,
          });
        }
        return isFavorite;
      } catch (error) {
        debugPrint('[FAVORITES] Saved locally; remote update pending: $error');
      }
    }
    return !wasFavorite;
  }

  Future<void> syncFavorites() async {
    final userId = _userId;
    if (userId == null || !await checkConnectivity()) return;

    if (!DatabaseHelper.isSupported) {
      await _fetchRemoteFavorites();
      return;
    }

    try {
      final response = await apiClient.get(ApiEndpoints.favorites);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final remoteData = response.data['data'] as List<dynamic>;
        final remoteIds = <String>{};
        for (final item in remoteData) {
          final row = item as Map<String, dynamic>;
          final id = row['id'].toString();
          remoteIds.add(id);
          final local = await dbHelper
              .query('favorites', where: 'id = ?', whereArgs: [id]);
          if (local.isEmpty) {
            final cleanRemote = <String, dynamic>{
              'id': id,
              'user_id': row['user_id'].toString(),
              'favoritable_type': row['favoritable_type'].toString(),
              'favoritable_id': row['favoritable_id'].toString(),
              'created_at': row['created_at']?.toString(),
              'updated_at': row['updated_at']?.toString(),
              'sync_status': 'synced',
              'dirty': 0,
              'pending_delete': 0,
            };
            await dbHelper.insert('favorites', cleanRemote);
          }
        }
        final syncedLocal = await dbHelper.query(
          'favorites',
          where: 'user_id = ? AND dirty = 0',
          whereArgs: [userId],
        );
        for (final row in syncedLocal) {
          if (!remoteIds.contains(row['id'].toString())) {
            await dbHelper
                .delete('favorites', where: 'id = ?', whereArgs: [row['id']]);
          }
        }
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteFavorites() async {
    final response = await apiClient.get(ApiEndpoints.favorites);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid favorites response.');
    }
    final rows = response.data['data'];
    if (rows is! List) throw const FormatException('Invalid favorites data.');
    return rows.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Set<FavoriteKey>> getFavoriteKeys({bool refreshRemote = true}) async {
    final userId = _userId;
    if (userId == null) return <FavoriteKey>{};

    if (!DatabaseHelper.isSupported) {
      if (!await checkConnectivity()) return <FavoriteKey>{};
      final rows = await _fetchRemoteFavorites();
      return rows.map(FavoriteKey.fromJson).toSet();
    }

    if (refreshRemote && await checkConnectivity()) {
      await syncFavorites();
    }
    final rows = await dbHelper.query(
      'favorites',
      where: 'user_id = ? AND pending_delete = 0',
      whereArgs: [userId],
    );
    return rows.map(FavoriteKey.fromJson).toSet();
  }
}

class FavoriteKey {
  const FavoriteKey(this.type, this.id);

  final String type;
  final String id;

  factory FavoriteKey.fromJson(Map<String, dynamic> json) => FavoriteKey(
        FavoritesRepository.normalizeType(
          json['favoritable_type']?.toString() ?? '',
        ),
        json['favoritable_id']?.toString() ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is FavoriteKey && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

class FavoritesNotifier extends StateNotifier<AsyncValue<Set<FavoriteKey>>> {
  FavoritesNotifier(this._repository) : super(const AsyncValue.loading()) {
    Future<void>.microtask(reload);
  }

  final FavoritesRepository _repository;
  bool _busy = false;

  bool contains(String type, String id) =>
      state.valueOrNull?.contains(
        FavoriteKey(FavoritesRepository.normalizeType(type), id),
      ) ??
      false;

  Future<void> reload() async {
    try {
      state = AsyncValue.data(await _repository.getFavoriteKeys());
    } catch (error, stack) {
      if (state.valueOrNull == null) state = AsyncValue.error(error, stack);
    }
  }

  Future<bool> toggle(String type, String id) async {
    if (_busy) return contains(type, id);
    _busy = true;
    final key = FavoriteKey(FavoritesRepository.normalizeType(type), id);
    final previous = Set<FavoriteKey>.of(state.valueOrNull ?? const {});
    final next = Set<FavoriteKey>.of(previous);
    final adding = !next.remove(key);
    if (adding) next.add(key);
    state = AsyncValue.data(next);
    try {
      final remoteState = await _repository.toggleFavorite(key.type, key.id);
      final confirmed = Set<FavoriteKey>.of(next);
      if (remoteState) {
        confirmed.add(key);
      } else {
        confirmed.remove(key);
      }
      state = AsyncValue.data(confirmed);
      return remoteState;
    } catch (error) {
      state = AsyncValue.data(previous);
      rethrow;
    } finally {
      _busy = false;
    }
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return FavoritesRepository(apiClient: client, ref: ref);
});

final favoriteKeysProvider =
    StateNotifierProvider<FavoritesNotifier, AsyncValue<Set<FavoriteKey>>>(
        (ref) {
  ref.watch(authProvider);
  ref.watch(connectivityProvider);
  return FavoritesNotifier(ref.watch(favoritesRepositoryProvider));
});

final isFavoriteProvider = Provider.family<bool, FavoriteKey>((ref, key) {
  return ref.watch(favoriteKeysProvider).valueOrNull?.contains(key) ?? false;
});
