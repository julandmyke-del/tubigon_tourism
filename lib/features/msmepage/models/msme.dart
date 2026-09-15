import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class Msme {
  final int id;
  final String uuid;
  final String? profileId;
  final String name;
  final String category;
  final String? categoryId;
  final String description;
  final String? phone;
  final String? address;
  final String? businessHours;
  final double? rating;
  final int reviewCount;
  final double? latitude;
  final double? longitude;
  final Color color;
  final IconData icon;
  final String tagline;
  final bool isVerified;
  final bool bookingEnabled;
  final String operationalStatus;
  final Map<String, dynamic> openingHours;
  final List<String> unavailableDates;
  final List<String> images;
  final List<MsmeProduct> products;
  final List<MsmeReview> reviews;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get ownerName => tagline.isNotEmpty ? tagline : 'Local Business Owner';
  String get contactNumber => phone ?? 'N/A';

  const Msme({
    required this.id,
    required this.uuid,
    this.profileId,
    required this.name,
    required this.category,
    this.categoryId,
    required this.description,
    this.phone,
    this.address,
    this.businessHours,
    this.rating,
    required this.reviewCount,
    this.latitude,
    this.longitude,
    required this.color,
    required this.icon,
    required this.tagline,
    required this.isVerified,
    this.bookingEnabled = false,
    this.operationalStatus = 'open',
    this.openingHours = const {},
    this.unavailableDates = const [],
    this.images = const [],
    required this.products,
    required this.reviews,
    this.createdAt,
    this.updatedAt,
  });

  factory Msme.fromJson(Map<String, dynamic> json) {
    List<MsmeProduct> parseProducts(dynamic val) {
      if (val == null) return [];
      if (val is List) {
        return val
            .map((e) => MsmeProduct.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded
                .map((e) => MsmeProduct.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        } catch (_) {}
      }
      return [];
    }

    List<MsmeReview> parseReviews(dynamic val) {
      if (val == null) return [];
      if (val is List) {
        return val
            .map((e) => MsmeReview.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded
                .map((e) => MsmeReview.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        } catch (_) {}
      }
      return [];
    }

    final cat = json['category'] as String? ?? 'Handicrafts';
    final rawId = json['id'];
    return Msme(
      id: _asInt(json['integer_id']) ?? _asInt(rawId) ?? 0,
      uuid: json['uuid']?.toString() ?? (rawId is String ? rawId : ''),
      profileId: json['profile_id'] as String?,
      name: json['name'] as String? ?? '',
      category: cat,
      categoryId: json['category_id']?.toString(),
      description: json['description'] as String? ?? '',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      businessHours: json['business_hours'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      color: _parseColor(json['color'], _getDefaultColor(cat)),
      icon: _parseIcon(json['icon'], _getDefaultIcon(cat)),
      tagline: json['tagline'] as String? ?? '',
      isVerified: (json['is_verified'] == true) || (json['is_verified'] == 1),
      bookingEnabled:
          (json['booking_enabled'] == true) || (json['booking_enabled'] == 1),
      operationalStatus: json['operational_status']?.toString() ?? 'open',
      openingHours: _asMap(json['opening_hours']),
      unavailableDates: _asStringList(json['unavailable_dates']),
      images: _asStringList(json['images']),
      products: parseProducts(json['products']),
      reviews: parseReviews(json['reviews']),
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

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList(growable: false);
        }
      } catch (_) {}
    }
    return const [];
  }

  bool isAvailableOn(DateTime date) {
    if (!bookingEnabled || operationalStatus != 'open') return false;
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (unavailableDates.contains(key)) return false;
    const weekdays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final hours = openingHours[weekdays[date.weekday - 1]];
    return hours is! Map || hours['closed'] != true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'profile_id': profileId,
      'name': name,
      'category': category,
      'category_id': categoryId,
      'description': description,
      'phone': phone,
      'address': address,
      'business_hours': businessHours,
      'rating': rating,
      'review_count': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'icon': _getIconString(icon),
      'tagline': tagline,
      'is_verified': isVerified ? 1 : 0,
      'booking_enabled': bookingEnabled ? 1 : 0,
      'operational_status': operationalStatus,
      'opening_hours': jsonEncode(openingHours),
      'unavailable_dates': jsonEncode(unavailableDates),
      'images': jsonEncode(images),
      'products': jsonEncode(products.map((p) => p.toJson()).toList()),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static Color _parseColor(dynamic val, Color defaultColor) {
    if (val == null) return defaultColor;
    final colorStr = val.toString();
    if (colorStr.startsWith('#')) {
      final buffer = StringBuffer();
      if (colorStr.length == 7) buffer.write('ff');
      buffer.write(colorStr.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    }
    final parsedInt = int.tryParse(colorStr);
    if (parsedInt != null) return Color(parsedInt);
    return defaultColor;
  }

  static Color _getDefaultColor(String category) {
    switch (category) {
      case 'Food & Dining':
        return AppColors.categoryFood;
      case 'Tour Services':
        return AppColors.categoryBeach;
      case 'Handicrafts':
        return AppColors.categoryCultural;
      case 'Agriculture':
        return AppColors.categoryEco;
      case 'Accommodation':
        return AppColors.categoryAccommodation;
      default:
        return AppColors.primary;
    }
  }

  static IconData _getDefaultIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant_rounded;
      case 'Tour Services':
        return Icons.sailing_rounded;
      case 'Handicrafts':
        return Icons.local_offer_rounded;
      case 'Agriculture':
        return Icons.agriculture_rounded;
      case 'Accommodation':
        return Icons.home_rounded;
      default:
        return Icons.store_rounded;
    }
  }

  static IconData _parseIcon(dynamic val, IconData defaultIcon) {
    if (val == null) return defaultIcon;
    final iconStr = val.toString();
    switch (iconStr) {
      case 'local_offer':
      case 'local_offer_rounded':
        return Icons.local_offer_rounded;
      case 'restaurant':
      case 'restaurant_rounded':
        return Icons.restaurant_rounded;
      case 'sailing':
      case 'sailing_rounded':
        return Icons.sailing_rounded;
      case 'agriculture':
      case 'agriculture_rounded':
        return Icons.agriculture_rounded;
      case 'bakery_dining':
      case 'bakery_dining_rounded':
        return Icons.bakery_dining_rounded;
      case 'home':
      case 'home_rounded':
        return Icons.home_rounded;
      default:
        return defaultIcon;
    }
  }

  static String _getIconString(IconData icon) {
    if (icon == Icons.local_offer_rounded) return 'local_offer_rounded';
    if (icon == Icons.restaurant_rounded) return 'restaurant_rounded';
    if (icon == Icons.sailing_rounded) return 'sailing_rounded';
    if (icon == Icons.agriculture_rounded) return 'agriculture_rounded';
    if (icon == Icons.bakery_dining_rounded) return 'bakery_dining_rounded';
    if (icon == Icons.home_rounded) return 'home_rounded';
    return 'store';
  }
}

class MsmeProduct {
  final String name;
  final String description;
  final double price;
  final IconData icon;
  const MsmeProduct(
      {required this.name,
      required this.description,
      required this.price,
      required this.icon});
  factory MsmeProduct.fromJson(Map<String, dynamic> json) {
    return MsmeProduct(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        icon: _parseProductIcon(json['icon']));
  }
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'icon': _getProductIconString(icon)
    };
  }

  static IconData _parseProductIcon(dynamic val) {
    if (val == null) return Icons.shopping_bag_rounded;
    final iconStr = val.toString();
    switch (iconStr) {
      case 'grid_on':
      case 'grid_on_rounded':
        return Icons.grid_on_rounded;
      case 'shopping_bag':
      case 'shopping_bag_rounded':
        return Icons.shopping_bag_rounded;
      case 'face':
      case 'face_rounded':
        return Icons.face_rounded;
      case 'dinner_dining':
      case 'dinner_dining_rounded':
        return Icons.dinner_dining_rounded;
      case 'set_meal':
      case 'set_meal_rounded':
        return Icons.set_meal_rounded;
      case 'fastfood':
      case 'fastfood_rounded':
        return Icons.fastfood_rounded;
      case 'sailing':
      case 'sailing_rounded':
        return Icons.sailing_rounded;
      case 'scuba_diving':
      case 'scuba_diving_rounded':
        return Icons.scuba_diving_rounded;
      case 'waves':
      case 'waves_rounded':
        return Icons.waves_rounded;
      case 'restaurant_menu':
      case 'restaurant_menu_rounded':
        return Icons.restaurant_menu_rounded;
      case 'eco':
      case 'eco_rounded':
        return Icons.eco_rounded;
      case 'tour':
      case 'tour_rounded':
        return Icons.tour_rounded;
      case 'cookie':
      case 'cookie_rounded':
        return Icons.cookie_rounded;
      case 'lunch_dining':
      case 'lunch_dining_rounded':
        return Icons.lunch_dining_rounded;
      case 'cake':
      case 'cake_rounded':
        return Icons.cake_rounded;
      case 'single_bed_rounded':
      case 'single_bed':
        return Icons.single_bed_rounded;
      case 'bed':
      case 'bed_rounded':
        return Icons.bed_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  static String _getProductIconString(IconData icon) {
    if (icon == Icons.grid_on_rounded) return 'grid_on_rounded';
    if (icon == Icons.shopping_bag_rounded) return 'shopping_bag_rounded';
    if (icon == Icons.face_rounded) return 'face_rounded';
    if (icon == Icons.dinner_dining_rounded) return 'dinner_dining_rounded';
    if (icon == Icons.set_meal_rounded) return 'set_meal_rounded';
    if (icon == Icons.fastfood_rounded) return 'fastfood_rounded';
    if (icon == Icons.sailing_rounded) return 'sailing_rounded';
    if (icon == Icons.scuba_diving_rounded) return 'scuba_diving_rounded';
    if (icon == Icons.waves_rounded) return 'waves_rounded';
    if (icon == Icons.restaurant_menu_rounded) return 'restaurant_menu_rounded';
    if (icon == Icons.eco_rounded) return 'eco_rounded';
    if (icon == Icons.tour_rounded) return 'tour_rounded';
    if (icon == Icons.cookie_rounded) return 'cookie_rounded';
    if (icon == Icons.lunch_dining_rounded) return 'lunch_dining_rounded';
    if (icon == Icons.cake_rounded) return 'cake_rounded';
    if (icon == Icons.single_bed_rounded) return 'single_bed_rounded';
    if (icon == Icons.bed_rounded) return 'bed_rounded';
    return 'shopping_bag';
  }
}

class MsmeReview {
  final String author;
  final double rating;
  final String comment;
  final String date;
  const MsmeReview(
      {required this.author,
      required this.rating,
      required this.comment,
      required this.date});
  factory MsmeReview.fromJson(Map<String, dynamic> json) {
    return MsmeReview(
        author: json['author'] as String? ?? 'Traveler',
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        comment: json['comment'] as String? ?? '',
        date: json['date'] as String? ?? '');
  }
  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'rating': rating,
      'comment': comment,
      'date': date
    };
  }
}

const msmeCategories = [
  'All',
  'Food & Dining',
  'Tour Services',
  'Handicrafts',
  'Agriculture',
  'Accommodation'
];
