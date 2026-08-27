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
  final String description;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TouristSpot({
    required this.id,
    required this.uuid,
    required this.name,
    required this.slug,
    required this.description,
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

    return TouristSpot(
      id: _asInt(json['integer_id']) ?? _asInt(rawId) ?? 0,
      uuid: json['uuid']?.toString() ?? (rawId is String ? rawId : ''),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categoryId: _asInt(catMap?['integer_id']) ?? _asInt(json['category_id']),
      categoryName: catName ?? 'Nature',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 9.9489,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 123.9583,
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
      'description': description,
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
