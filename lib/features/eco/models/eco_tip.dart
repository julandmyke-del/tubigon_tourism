import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class EcoTip {
  const EcoTip({
    required this.id,
    required this.uuid,
    required this.title,
    required this.content,
    required this.category,
    required this.icon,
    required this.color,
    this.shortMessage,
    this.spotId,
    this.spotName,
    this.language = 'en',
    this.priority = 0,
    this.startsAt,
    this.endsAt,
  });

  final int id;
  final String uuid;
  final String title;
  final String content;
  final String category;
  final IconData icon;
  final Color color;
  final String? shortMessage;
  final String? spotId;
  final String? spotName;
  final String language;
  final int priority;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory EcoTip.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString().toLowerCase() ?? 'general';
    final appearance = _appearance(category);
    final spot = json['spot'];
    return EcoTip(
      id: _asInt(json['integer_id']) ?? _asInt(json['id']) ?? 0,
      uuid: json['uuid']?.toString() ??
          (json['id'] is String ? json['id'].toString() : ''),
      title: json['title']?.toString() ?? 'Eco guidance',
      shortMessage: json['short_message']?.toString(),
      content: json['content']?.toString() ?? '',
      category: category,
      icon: appearance.$1,
      color: appearance.$2,
      spotId: json['spot_id']?.toString(),
      spotName: spot is Map ? spot['name']?.toString() : null,
      language: json['language']?.toString() ?? 'en',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? ''),
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? ''),
    );
  }

  static (IconData, Color) _appearance(String category) => switch (category) {
        'marine' => (Icons.beach_access_rounded, AppColors.categoryBeach),
        'waste' => (Icons.recycling_rounded, AppColors.accentDark),
        'nature' => (Icons.hiking_rounded, AppColors.categoryNature),
        'wildlife' => (Icons.pets_rounded, AppColors.categoryAdventure),
        'community' => (Icons.store_rounded, AppColors.categoryCultural),
        'resources' => (Icons.water_drop_rounded, AppColors.secondary),
        'transport' => (Icons.directions_transit_rounded, AppColors.warning),
        _ => (Icons.eco_rounded, AppColors.primary),
      };

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'title': title,
        'short_message': shortMessage,
        'content': content,
        'category': category,
        'spot_id': spotId,
        'language': language,
        'priority': priority,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'is_active': 1,
        'is_published': 1,
      };
}
