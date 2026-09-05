import 'dart:convert';

class SpotCategory {
  final int id;
  final String uuid;
  final String name;
  final String slug;

  SpotCategory({
    required this.id,
    required this.uuid,
    required this.name,
    required this.slug,
  });

  factory SpotCategory.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return SpotCategory(
      id: _asInt(json['integer_id']) ?? _asInt(rawId) ?? 0,
      uuid: json['uuid']?.toString() ?? (rawId is String ? rawId : ''),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'slug': slug,
    };
  }
}

class TouristSpot {
  final int id;
  final String uuid;
  final String name;
  final String slug;
  final String shortDescription;
  final String description;
  final List<String> aliases;
  final int? categoryId;
  final String? categoryName; // Denormalized category name for UI convenience
  final double latitude;
  final double longitude;
  final String address;
  final double entranceFee;
  final String openingHours;
  final List<String> ecoTips;
  final List<String> images;
  final double averageRating;
  final int reviewCount;
  final bool isFeatured;
  final bool isActive;
  final bool isPublished;
  final bool isBookable;
  final bool bookingEnabled;
  final String? bookingUnavailableReasonCode;
  final String? bookingUnavailableReason;
  final DateTime? bookingAvailabilityUpdatedAt;
  final String bookingMode;
  final List<String> bookingAvailableDays;
  final List<Map<String, dynamic>> bookingTimeSlots;
  final int? maxGuestsPerReservation;
  final int? advanceBookingDays;
  final int? minimumNoticeHours;
  final double? reservationFee;
  final bool feeConfigured;
  final String? bookingInstructions;
  final String? cancellationPolicy;
  final String? contactInformation;
  final String? visitorInstructions;
  final List<String> amenities;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TouristSpot({
    required this.id,
    required this.uuid,
    required this.name,
    required this.slug,
    this.shortDescription = '',
    required this.description,
    this.aliases = const [],
    this.categoryId,
    this.categoryName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.entranceFee,
    required this.openingHours,
    required this.ecoTips,
    required this.images,
    required this.averageRating,
    required this.reviewCount,
    required this.isFeatured,
    required this.isActive,
    this.isPublished = true,
    this.isBookable = false,
    this.bookingEnabled = false,
    this.bookingUnavailableReasonCode,
    this.bookingUnavailableReason,
    this.bookingAvailabilityUpdatedAt,
    this.bookingMode = 'no_reservation',
    this.bookingAvailableDays = const [],
    this.bookingTimeSlots = const [],
    this.maxGuestsPerReservation,
    this.advanceBookingDays,
    this.minimumNoticeHours,
    this.reservationFee,
    this.feeConfigured = false,
    this.bookingInstructions,
    this.cancellationPolicy,
    this.contactInformation,
    this.visitorInstructions,
    this.amenities = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory TouristSpot.fromJson(Map<String, dynamic> json) {
    // Parse list of strings for images & tips
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String) {
        if (val.startsWith('[') && val.endsWith(']')) {
          try {
            // JSON array format
            return (val.replaceAll(RegExp(r'[\[\]" ]'), '').split(','))
                .where((s) => s.isNotEmpty)
                .toList();
          } catch (_) {}
        }
        return val.split(',').where((s) => s.isNotEmpty).toList();
      }
      return [];
    }

    final catMap =
        (json['category'] ?? json['spot_categories']) as Map<String, dynamic>?;
    final catName = catMap != null
        ? catMap['name'] as String?
        : json['category_name'] as String?;
    final rawId = json['id'];
    List<Map<String, dynamic>> parseSlots(dynamic value) {
      dynamic decoded = value;
      if (value is String && value.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(value);
        } catch (_) {
          return const [];
        }
      }
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((slot) => Map<String, dynamic>.from(slot))
          .toList(growable: false);
    }

    return TouristSpot(
      id: _asInt(json['integer_id']) ?? _asInt(rawId) ?? 0,
      uuid: json['uuid']?.toString() ?? (rawId is String ? rawId : ''),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      shortDescription: json['short_description'] as String? ?? '',
      description: json['description'] as String? ?? '',
      aliases: parseList(json['aliases']),
      categoryId: _asInt(catMap?['integer_id']) ?? _asInt(json['category_id']),
      categoryName: catName ?? 'Nature',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String? ?? '',
      entranceFee: (json['entrance_fee'] as num?)?.toDouble() ?? 0.0,
      openingHours: json['opening_hours'] as String? ?? '',
      ecoTips: parseList(json['eco_tips']),
      images: parseList(json['images']),
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      isFeatured: (json['is_featured'] == true) || (json['is_featured'] == 1),
      isActive: (json['is_active'] == true) ||
          (json['is_active'] == null) ||
          (json['is_active'] == 1),
      isPublished: (json['is_published'] == true) ||
          (json['is_published'] == null) ||
          (json['is_published'] == 1),
      isBookable: (json['is_bookable'] == true) || (json['is_bookable'] == 1),
      bookingEnabled:
          (json['booking_enabled'] == true) || (json['booking_enabled'] == 1),
      bookingUnavailableReasonCode:
          json['booking_unavailable_reason_code']?.toString(),
      bookingUnavailableReason: json['booking_unavailable_reason']?.toString(),
      bookingAvailabilityUpdatedAt: DateTime.tryParse(
          json['booking_availability_updated_at']?.toString() ?? ''),
      bookingMode: json['booking_mode']?.toString() ?? 'no_reservation',
      bookingAvailableDays: parseList(json['booking_available_days']),
      bookingTimeSlots: parseSlots(json['booking_time_slots']),
      maxGuestsPerReservation: _asInt(json['max_guests_per_reservation']),
      advanceBookingDays: _asInt(json['advance_booking_days']),
      minimumNoticeHours: _asInt(json['minimum_notice_hours']),
      reservationFee: (json['reservation_fee'] as num?)?.toDouble(),
      feeConfigured:
          json['fee_configured'] == true || json['fee_configured'] == 1,
      bookingInstructions: json['booking_instructions']?.toString(),
      cancellationPolicy: json['cancellation_policy']?.toString(),
      contactInformation: json['contact_information']?.toString(),
      visitorInstructions: json['visitor_instructions']?.toString(),
      amenities: parseList(json['amenities']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'slug': slug,
      'short_description': shortDescription,
      'description': description,
      'aliases': jsonEncode(aliases),
      'category_id': categoryId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'entrance_fee': entranceFee,
      'opening_hours': openingHours,
      'eco_tips': ecoTips.join(','),
      'images': images.join(','),
      'average_rating': averageRating,
      'review_count': reviewCount,
      'is_featured': isFeatured ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_published': isPublished ? 1 : 0,
      'is_bookable': isBookable ? 1 : 0,
      'booking_enabled': bookingEnabled ? 1 : 0,
      'booking_unavailable_reason_code': bookingUnavailableReasonCode,
      'booking_unavailable_reason': bookingUnavailableReason,
      'booking_availability_updated_at':
          bookingAvailabilityUpdatedAt?.toIso8601String(),
      'booking_mode': bookingMode,
      'booking_available_days': bookingAvailableDays.join(','),
      'booking_time_slots': jsonEncode(bookingTimeSlots),
      'max_guests_per_reservation': maxGuestsPerReservation,
      'advance_booking_days': advanceBookingDays,
      'minimum_notice_hours': minimumNoticeHours,
      'reservation_fee': reservationFee,
      'fee_configured': feeConfigured ? 1 : 0,
      'booking_instructions': bookingInstructions,
      'cancellation_policy': cancellationPolicy,
      'contact_information': contactInformation,
      'visitor_instructions': visitorInstructions,
      'amenities': amenities.join(','),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get canAcceptBookings =>
      isActive && isPublished && isBookable && bookingEnabled;

  bool get hasCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);

  String get bookingUnavailableLabel {
    final code = bookingUnavailableReasonCode?.trim();
    if (code == null || code.isEmpty) return 'Temporarily unavailable';
    return code
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
