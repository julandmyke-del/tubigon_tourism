import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../database/database_helper.dart';
import '../../authentication/auth_provider.dart';
import '../models/reservation.dart';

class ReservationRepository {
  ReservationRepository({required this.apiClient, required this.ref});

  final ApiClient apiClient;
  final Ref ref;
  final dbHelper = DatabaseHelper.instance;

  String? get _userId => ref.read(authProvider).userId;

  Map<String, dynamic> _remoteReservationRow(Map<String, dynamic> row) {
    final statusMap = row['status'] as Map<String, dynamic>?;
    final rawDate = row['reservation_date']?.toString() ?? '';
    final reservationDate =
        rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    return {
      'id': row['id'].toString(),
      'user_id': row['user_id'].toString(),
      'partner_id': row['partner_id']?.toString(),
      'reservable_type': row['reservable_type'].toString(),
      'reservable_id': row['reservable_id'].toString(),
      'reservation_date': reservationDate,
      'start_time': row['start_time']?.toString(),
      'end_time': row['end_time']?.toString(),
      'guests': (row['guests'] as num?)?.toInt() ?? 1,
      'status': statusMap?['name']?.toString() ?? 'pending',
      'notes': row['notes']?.toString(),
      'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
      'created_at': row['created_at']?.toString(),
      'updated_at': row['updated_at']?.toString(),
      'sync_status': 'synced',
      'dirty': 0,
      'pending_delete': 0,
    };
  }

  /// Fetches reservations list. Performs local metadata joins for spots/MSMEs.
  Future<List<Reservation>> getReservations() async {
    final userId = _userId;
    if (userId == null) return [];

    if (!DatabaseHelper.isSupported) {
      return _fetchRemoteReservations();
    }

    // 1. Fetch remote if online
    if (SyncService.instance.isOnline) {
      try {
        await SyncService.instance.syncTableToRemote('reservations');

        final response = await apiClient.get(ApiEndpoints.reservations);

        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final remoteData = response.data['data'] as List<dynamic>;

          for (final item in remoteData) {
            final row = item as Map<String, dynamic>;
            final uuid = row['id'].toString();

            final local = await dbHelper
                .query('reservations', where: 'id = ?', whereArgs: [uuid]);

            final reservationJson = _remoteReservationRow(row);

            if (local.isEmpty) {
              await dbHelper.insert('reservations', reservationJson);
            } else {
              final localRow = local.first;
              if ((localRow['dirty'] as int? ?? 0) == 0) {
                await dbHelper.update('reservations', reservationJson,
                    where: 'id = ?', whereArgs: [uuid]);
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Load from SQLite
    final localResult = await dbHelper.query(
      'reservations',
      where: 'user_id = ? AND pending_delete = 0',
      whereArgs: [userId],
      orderBy: 'reservation_date DESC',
    );

    final List<Reservation> reservations = [];
    for (final row in localResult) {
      final reservableType = row['reservable_type'] as String;
      final reservableId = row['reservable_id'] as String;

      String name = 'Reservation';
      Color color = Colors.teal;
      IconData icon = Icons.calendar_today_rounded;

      if (reservableType == 'spot') {
        final spots = await dbHelper.query('tourist_spots',
            where: 'uuid = ?', whereArgs: [reservableId]);
        if (spots.isNotEmpty) {
          name = spots.first['name'] as String;
          final catId = spots.first['category_id'] as int?;
          if (catId != null) {
            final cats = await dbHelper
                .query('spot_categories', where: 'id = ?', whereArgs: [catId]);
            if (cats.isNotEmpty) {
              final catName = cats.first['name'] as String;
              if (catName == 'Beach') {
                color = AppColors.categoryBeach;
                icon = Icons.beach_access_rounded;
              } else if (catName == 'Nature') {
                color = AppColors.categoryNature;
                icon = Icons.landscape_rounded;
              } else if (catName == 'Historical') {
                color = AppColors.categoryHistorical;
                icon = Icons.account_balance_rounded;
              } else if (catName == 'Adventure') {
                color = AppColors.categoryAdventure;
                icon = Icons.surfing_rounded;
              } else if (catName == 'Eco') {
                color = AppColors.categoryEco;
                icon = Icons.eco_rounded;
              } else if (catName == 'Cultural') {
                color = AppColors.categoryCultural;
                icon = Icons.theater_comedy_rounded;
              }
            }
          }
        }
      } else if (reservableType == 'msme') {
        final msmes = await dbHelper
            .query('msmes', where: 'uuid = ?', whereArgs: [reservableId]);
        if (msmes.isNotEmpty) {
          name = msmes.first['name'] as String;
          final category = msmes.first['category'] as String;
          if (category == 'Food & Dining') {
            color = AppColors.categoryFood;
            icon = Icons.restaurant_rounded;
          } else if (category == 'Tour Services') {
            color = AppColors.categoryBeach;
            icon = Icons.sailing_rounded;
          } else if (category == 'Handicrafts') {
            color = AppColors.categoryCultural;
            icon = Icons.local_offer_rounded;
          } else if (category == 'Agriculture') {
            color = AppColors.categoryEco;
            icon = Icons.agriculture_rounded;
          } else if (category == 'Accommodation') {
            color = AppColors.categoryAccommodation;
            icon = Icons.home_rounded;
          }
        }
      }

      reservations
          .add(Reservation.fromJson(row, name: name, color: color, icon: icon));
    }

    return reservations;
  }

  /// Submits a new booking offline first.
  Future<bool> createReservation({
    required String reservableType,
    required String reservableId,
    required String date,
    required String? startTime,
    required int guests,
    required double pricePerGuest,
    String? notes,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Must be logged in to book.');
    final hasNetwork = await checkConnectivity();
    if (!hasNetwork) {
      throw Exception('New reservations require an internet connection.');
    }

    if (!DatabaseHelper.isSupported) {
      return _createRemoteReservation(
        reservableType: reservableType,
        reservableId: reservableId,
        date: date,
        startTime: startTime,
        guests: guests,
        notes: notes,
      );
    }

    final resId = const Uuid().v4();
    final total = pricePerGuest * guests;

    final duplicate = await dbHelper.query(
      'reservations',
      where:
          'user_id = ? AND reservable_type = ? AND reservable_id = ? AND reservation_date = ? AND start_time = ? AND status NOT IN (?, ?) AND pending_delete = 0',
      whereArgs: [
        userId,
        reservableType,
        reservableId,
        date,
        startTime,
        'cancelled',
        'rejected'
      ],
    );
    if (duplicate.isNotEmpty) {
      throw Exception(
          'You already have a reservation for this place and time.');
    }

    final reservationJson = {
      'id': resId,
      'user_id': userId,
      'reservable_type': reservableType,
      'reservable_id': reservableId,
      'reservation_date': date,
      'start_time': startTime,
      'end_time': null,
      'guests': guests,
      'status': 'pending',
      'notes': notes,
      'total_amount': total,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'dirty': 1,
      'sync_status': 'pending_insert',
      'pending_delete': 0,
    };

    await dbHelper.insert('reservations', reservationJson);

    // Sync in background if online
    if (hasNetwork) {
      try {
        final response = await apiClient.post(
          ApiEndpoints.reservations,
          data: {
            'reservable_type': reservableType,
            'reservable_id': reservableId,
            'reservation_date': date,
            'start_time': startTime,
            'guests': guests,
            'notes': notes,
          },
        );

        if (response.statusCode == 201 &&
            response.data['status'] == 'success') {
          final serverRow = _remoteReservationRow(
            response.data['data'] as Map<String, dynamic>,
          );
          await dbHelper
              .delete('reservations', where: 'id = ?', whereArgs: [resId]);
          await dbHelper.insert('reservations', serverRow);
          return true;
        }
        throw Exception('The reservation could not be accepted by the server.');
      } catch (_) {
        await dbHelper
            .delete('reservations', where: 'id = ?', whereArgs: [resId]);
        rethrow;
      }
    }
    return false;
  }

  /// Cancels a booking locally first.
  Future<void> cancelReservation(String uuid) async {
    if (!DatabaseHelper.isSupported) {
      final response =
          await apiClient.put(ApiEndpoints.cancelReservation(uuid));
      if (response.statusCode != 200 || response.data['status'] != 'success') {
        throw Exception('Unable to cancel the reservation. Please try again.');
      }
      return;
    }

    final local = await dbHelper
        .query('reservations', where: 'id = ?', whereArgs: [uuid]);
    if (local.isEmpty) return;

    if (SyncService.instance.isOnline) {
      try {
        await apiClient.put(ApiEndpoints.cancelReservation(uuid));

        await dbHelper.update(
          'reservations',
          {
            'status': 'cancelled',
            'sync_status': 'synced',
            'dirty': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [uuid],
        );
        return;
      } catch (_) {}
    }

    await dbHelper.update(
      'reservations',
      {
        'status': 'cancelled',
        'dirty': 1,
        'sync_status': 'pending_update',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [uuid],
    );
  }

  Future<List<Reservation>> _fetchRemoteReservations() async {
    final response = await apiClient.get(ApiEndpoints.reservations);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid reservations response.');
    }
    final rows = response.data['data'];
    if (rows is! List) {
      throw const FormatException('Invalid reservations data.');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_remoteReservationRow)
        .map(Reservation.fromJson)
        .toList(growable: false);
  }

  Future<bool> _createRemoteReservation({
    required String reservableType,
    required String reservableId,
    required String date,
    required String? startTime,
    required int guests,
    required String? notes,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.reservations,
      data: {
        'reservable_type': reservableType,
        'reservable_id': reservableId,
        'reservation_date': date,
        'start_time': startTime,
        'guests': guests,
        'notes': notes,
      },
    );
    if (response.statusCode != 201 || response.data['status'] != 'success') {
      throw Exception('Unable to create the reservation. Please try again.');
    }
    return true;
  }
}

// ─── Riverpod Providers ────────────────────────────────────────────────────────

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ReservationRepository(apiClient: client, ref: ref);
});

final reservationsListProvider = FutureProvider<List<Reservation>>((ref) async {
  final repo = ref.watch(reservationRepositoryProvider);
  return repo.getReservations();
});

final userReservationsProvider = reservationsListProvider;
