import 'dart:convert';

import 'package:flutter/material.dart';

class Reservation {
  final String id;
  final String publicReference;
  final String userId;
  final String reservableType; // 'spot', 'msme'
  final String reservableId; // UUID of spot/MSME
  final String reservationDate;
  final String? startTime;
  final String? endTime;
  final int guests;
  final String status; // 'pending', 'confirmed', 'completed', 'cancelled'
  final String? notes;
  final double totalAmount;
  final String? createdAt;
  final String? updatedAt;
  final String? imageUrl;
  final bool feeConfigured;
  final String? bookingInstructions;
  final String? cancellationPolicy;
  final double? latitude;
  final double? longitude;
  final List<ReservationStatusEntry> statusHistory;
  final List<Map<String, dynamic>> items;

  // Joined fields for UI convenience
  final String spotName;
  final Color spotColor;
  final IconData spotIcon;

  String get spotTitle => spotName;
  String get touristName =>
      notes != null && notes!.isNotEmpty ? notes! : 'Tourist';
  int get numberOfGuests => guests;

  Reservation({
    required this.id,
    this.publicReference = '',
    required this.userId,
    required this.reservableType,
    required this.reservableId,
    required this.reservationDate,
    this.startTime,
    this.endTime,
    required this.guests,
    required this.status,
    this.notes,
    required this.totalAmount,
    this.createdAt,
    this.updatedAt,
    this.imageUrl,
    this.feeConfigured = false,
    this.bookingInstructions,
    this.cancellationPolicy,
    this.latitude,
    this.longitude,
    this.statusHistory = const [],
    this.items = const [],
    this.spotName = 'Reservation Item',
    this.spotColor = Colors.teal,
    this.spotIcon = Icons.calendar_today_rounded,
  });

  factory Reservation.fromJson(
    Map<String, dynamic> json, {
    String? name,
    Color? color,
    IconData? icon,
  }) {
    final rawHistory = json['status_history'];
    dynamic history = rawHistory;
    if (rawHistory is String && rawHistory.isNotEmpty) {
      try {
        history = jsonDecode(rawHistory);
      } catch (_) {
        history = const [];
      }
    }
    return Reservation(
      id: json['id'] as String? ?? '',
      publicReference: json['public_reference'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      reservableType: json['reservable_type'] as String? ?? 'spot',
      reservableId: json['reservable_id'] as String? ?? '',
      reservationDate: json['reservation_date'] as String? ?? '',
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      guests: json['guests'] as int? ?? 1,
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      imageUrl: json['reservable_image'] as String?,
      feeConfigured:
          json['fee_configured'] == true || json['fee_configured'] == 1,
      bookingInstructions: json['booking_instructions'] as String?,
      cancellationPolicy: json['cancellation_policy'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      statusHistory: history is List
          ? history
              .whereType<Map>()
              .map((item) => ReservationStatusEntry.fromJson(
                  Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const [],
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      spotName: name ??
          json['reservable_name'] as String? ??
          json['spot_name'] as String? ??
          'Location Spot',
      spotColor: color ?? Colors.teal,
      spotIcon: icon ?? Icons.calendar_today_rounded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'public_reference': publicReference,
      'user_id': userId,
      'reservable_type': reservableType,
      'reservable_id': reservableId,
      'reservation_date': reservationDate,
      'start_time': startTime,
      'end_time': endTime,
      'guests': guests,
      'status': status,
      'notes': notes,
      'total_amount': totalAmount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'reservable_name': spotName,
      'reservable_image': imageUrl,
      'fee_configured': feeConfigured ? 1 : 0,
      'booking_instructions': bookingInstructions,
      'cancellation_policy': cancellationPolicy,
      'latitude': latitude,
      'longitude': longitude,
      'status_history':
          jsonEncode(statusHistory.map((item) => item.toJson()).toList()),
    };
  }
}

class ReservationStatusEntry {
  const ReservationStatusEntry({required this.status, this.createdAt});

  final String status;
  final String? createdAt;

  factory ReservationStatusEntry.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    return ReservationStatusEntry(
      status: status is Map
          ? status['name']?.toString() ?? 'updated'
          : status?.toString() ?? 'updated',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'created_at': createdAt,
      };
}
