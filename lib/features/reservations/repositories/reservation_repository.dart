import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      'public_reference': row['public_reference']?.toString(),
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
      'reservable_name': row['reservable_name']?.toString(),
      'reservable_image': row['reservable_image']?.toString(),
      'fee_configured':
          row['fee_configured'] == true || row['fee_configured'] == 1 ? 1 : 0,
      'booking_instructions': row['booking_instructions']?.toString(),
      'cancellation_policy': row['cancellation_policy']?.toString(),
      'latitude': (row['latitude'] as num?)?.toDouble(),
      'longitude': (row['longitude'] as num?)?.toDouble(),
      'status_history': row['status_history'],
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

      String name = row['reservable_name']?.toString() ?? 'Reservation';
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

  Future<Reservation> getReservation(String id) async {
    if (await checkConnectivity()) {
      final response = await apiClient.get(ApiEndpoints.reservationById(id));
      if (response.statusCode != 200 || response.data['status'] != 'success') {
        throw Exception('Unable to load this reservation.');
      }
      final row = _remoteReservationRow(
        response.data['data'] as Map<String, dynamic>,
      );
      final reservation =
          Reservation.fromJson(row, name: row['reservable_name']?.toString());
      if (DatabaseHelper.isSupported) {
        await dbHelper.insert(
            'reservations',
            reservation.toJson()
              ..addAll(
                  {'sync_status': 'synced', 'dirty': 0, 'pending_delete': 0}));
      }
      return reservation;
    }
    if (DatabaseHelper.isSupported) {
      final rows = await dbHelper
          .query('reservations', where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) return Reservation.fromJson(rows.first);
    }
    throw Exception('Connect to the internet to load this reservation.');
  }

  /// A reservation exists only after Laravel confirms MySQL persistence.
  Future<Reservation> createReservation({
    required String reservableType,
    required String reservableId,
    required String date,
    required String? startTime,
    required int guests,
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

    final reservation = await _createRemoteReservation(
      reservableType: reservableType,
      reservableId: reservableId,
      date: date,
      startTime: startTime,
      guests: guests,
      notes: notes,
    );
    await dbHelper.insert(
        'reservations',
        reservation.toJson()
          ..addAll({'sync_status': 'synced', 'dirty': 0, 'pending_delete': 0}));
    return reservation;
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

    final localRow = local.first;
    if ((localRow['dirty'] as int? ?? 0) == 1 &&
        localRow['sync_status'] == 'pending_insert') {
      await dbHelper.delete('reservations', where: 'id = ?', whereArgs: [uuid]);
      return;
    }

    if (SyncService.instance.isOnline) {
      try {
        final response =
            await apiClient.put(ApiEndpoints.cancelReservation(uuid));
        if (response.statusCode != 200 ||
            response.data['status'] != 'success') {
          throw Exception('The server did not accept this cancellation.');
        }

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
      } catch (_) {
        rethrow;
      }
    }
    throw Exception(
        'Connect to the internet to cancel a confirmed reservation.');
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

  Future<Reservation> _createRemoteReservation({
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
    final row = _remoteReservationRow(
      response.data['data'] as Map<String, dynamic>,
    );
    return Reservation.fromJson(row, name: row['reservable_name']?.toString());
  }
}

// ─── Riverpod Providers ────────────────────────────────────────────────────────

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ReservationRepository(apiClient: client, ref: ref);
});

final reservationsListProvider = FutureProvider<List<Reservation>>((ref) async {
  ref.watch(
      authProvider.select((auth) => (auth.isLoggedIn, auth.userId, auth.role)));
  final repo = ref.watch(reservationRepositoryProvider);
  return repo.getReservations();
});

final userReservationsProvider = reservationsListProvider;

final reservationDetailProvider =
    FutureProvider.autoDispose.family<Reservation, String>((ref, id) async {
  return ref.watch(reservationRepositoryProvider).getReservation(id);
});
