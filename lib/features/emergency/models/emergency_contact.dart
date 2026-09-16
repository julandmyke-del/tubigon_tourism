import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class EmergencyContact {
  final int id;
  final String uuid;
  final String name;
  final String? contactLabel;
  final int displayOrder;
  final String category;
  final String phone;
  final String? alternativePhone;
  final String? address;
  final String? barangay;
  final String? description;
  final String? operatingHours;
  final String? availabilityNotes;
  final String? emergencyInstructions;
  final String classification;
  final bool isActive;
  final bool isVerified;
  final bool isPublic;
  final String verificationStatus;
  final String? source;
  final String? sourceName;
  final String? sourceUrl;
  final DateTime? verifiedAt;
  final DateTime? lastVerifiedAt;
  final DateTime? updatedAt;
  final String? updatedByName;
  final String? verifiedByName;
  final double? latitude;
  final double? longitude;
  final Color color;
  final IconData icon;

  String get phoneNumber => phone;

  const EmergencyContact({
    required this.id,
    required this.uuid,
    required this.name,
    this.contactLabel,
    this.displayOrder = 100,
    required this.category,
    required this.phone,
    this.alternativePhone,
    this.address,
    this.barangay,
    this.description,
    this.operatingHours,
    this.availabilityNotes,
    this.emergencyInstructions,
    this.classification = 'emergency',
    this.isActive = true,
    this.isVerified = false,
    this.isPublic = false,
    this.verificationStatus = 'draft',
    this.source,
    this.sourceName,
    this.sourceUrl,
    this.verifiedAt,
    this.lastVerifiedAt,
    this.updatedAt,
    this.updatedByName,
    this.verifiedByName,
    this.latitude,
    this.longitude,
    required this.color,
    required this.icon,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as String? ?? 'Emergency';

    // Resolve Icon and Color based on category
    Color c = AppColors.error;
    IconData ic = Icons.emergency_rounded;

    switch (cat.toLowerCase()) {
      case 'police':
        c = AppColors.secondary;
        ic = Icons.local_police_rounded;
        break;
      case 'fire':
        c = AppColors.error;
        ic = Icons.local_fire_department_rounded;
        break;
      case 'medical':
        c = AppColors.accentDark;
        ic = Icons.local_hospital_rounded;
        break;
      case 'government':
        c = AppColors.categoryCultural;
        ic = Icons.account_balance_rounded;
        break;
      case 'coast guard':
        c = AppColors.categoryBeach;
        ic = Icons.anchor_rounded;
        break;
      case 'red cross':
        c = AppColors.error;
        ic = Icons.medical_services_rounded;
        break;
      case 'disaster risk':
        c = AppColors.warning;
        ic = Icons.warning_rounded;
        break;
    }

    return EmergencyContact(
      id: _asInt(json['integer_id']) ?? _asInt(json['id']) ?? 0,
      uuid: json['uuid']?.toString() ??
          (json['id'] is String ? json['id'].toString() : ''),
      name: (json['name'] ?? json['agency_name'])?.toString() ?? 'Agency',
      contactLabel: json['contact_label']?.toString(),
      displayOrder: _asInt(json['display_order']) ?? 100,
      category: cat,
      phone: (json['phone'] ?? json['phone_number'])?.toString() ?? '',
      alternativePhone: json['alternative_phone'] as String?,
      address: json['address'] as String?,
      barangay: json['barangay'] as String?,
      description: json['description'] as String?,
      operatingHours: json['operating_hours'] as String?,
      availabilityNotes: json['availability_notes'] as String?,
      emergencyInstructions: json['emergency_instructions'] as String?,
      classification: json['classification']?.toString() ?? 'emergency',
      isActive: _asBool(json['is_active'], fallback: true),
      isVerified: _asBool(json['is_verified']),
      isPublic: _asBool(json['is_public']),
      verificationStatus: json['verification_status']?.toString() ?? 'draft',
      source: json['source'] as String?,
      sourceName: json['source_name'] as String?,
      sourceUrl: json['source_url'] as String?,
      verifiedAt: _asDateTime(json['verified_at']),
      lastVerifiedAt: _asDateTime(json['last_verified_at']),
      updatedAt: _asDateTime(json['updated_at']),
      updatedByName:
          _relationName(json['updater']) ?? json['updated_by_name']?.toString(),
      verifiedByName: _relationName(json['verifier']) ??
          json['verified_by_name']?.toString(),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      icon: ic,
      color: c,
    );
  }

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    return value == true || value == 1 || value.toString() == '1';
  }

  static DateTime? _asDateTime(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  static String? _relationName(dynamic value) {
    if (value is! Map) return null;
    return value['name']?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'contact_label': contactLabel,
      'display_order': displayOrder,
      'category': category,
      'phone': phone,
      'alternative_phone': alternativePhone,
      'address': address,
      'barangay': barangay,
      'description': description,
      'operating_hours': operatingHours,
      'availability_notes': availabilityNotes,
      'emergency_instructions': emergencyInstructions,
      'classification': classification,
      'is_active': isActive ? 1 : 0,
      'is_verified': isVerified ? 1 : 0,
      'is_public': isPublic ? 1 : 0,
      'verification_status': verificationStatus,
      'source': source,
      'source_name': sourceName,
      'source_url': sourceUrl,
      'verified_at': verifiedAt?.toIso8601String(),
      'last_verified_at': lastVerifiedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by_name': updatedByName,
      'verified_by_name': verifiedByName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
