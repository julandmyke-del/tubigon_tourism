import 'package:flutter/material.dart';

class Reservation {
  final String id;
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

  // Joined fields for UI convenience
  final String spotName;
  final Color spotColor;
  final IconData spotIcon;

  String get spotTitle => spotName;
  String get touristName => notes != null && notes!.isNotEmpty ? notes! : 'Tourist';
  int get numberOfGuests => guests;

  Reservation({
    required this.id,
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
    this.spotName = 'Reservation Item',
    this.spotColor = Colors.teal,
    this.spotIcon = Icons.calendar_today_rounded,
  });

  factory Reservation.fromJson(Map<String, dynamic> json, {
    String? name,
    Color? color,
    IconData? icon,
  }) {
    return Reservation(
      id: json['id'] as String? ?? '',
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
      spotName: name ?? json['spot_name'] as String? ?? 'Location Spot',
      spotColor: color ?? Colors.teal,
      spotIcon: icon ?? Icons.calendar_today_rounded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
    };
  }
}
