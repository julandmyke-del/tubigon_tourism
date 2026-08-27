import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class EcoTip {
  final int id;
  final String uuid;
  final String title;
  final String content;
  final String category;
  final IconData icon;
  final Color color;

  const EcoTip({
    required this.id,
    required this.uuid,
    required this.title,
    required this.content,
    required this.category,
    required this.icon,
    required this.color,
  });

  factory EcoTip.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as String? ?? 'General';

    // Resolve Icon and Color based on category
    Color c = AppColors.primary;
    IconData ic = Icons.eco_rounded;

    switch (cat) {
      case 'Marine':
        c = AppColors.categoryBeach;
        ic = Icons.beach_access_rounded;
        break;
      case 'Waste':
        c = AppColors.accentDark;
        ic = Icons.recycling_rounded;
        break;
      case 'Nature':
        c = AppColors.categoryNature;
        ic = Icons.hiking_rounded;
        break;
      case 'Wildlife':
        c = AppColors.categoryAdventure;
        ic = Icons.pets_rounded;
        break;
      case 'Community':
        c = AppColors.categoryCultural;
        ic = Icons.store_rounded;
        break;
      case 'Resources':
        c = AppColors.secondary;
        ic = Icons.water_drop_rounded;
        break;
    }

    return EcoTip(
      id: _asInt(json['integer_id']) ?? _asInt(json['id']) ?? 0,
      uuid: json['uuid']?.toString() ??
          (json['id'] is String ? json['id'].toString() : ''),
      title: json['title'] as String? ?? 'Eco Tip',
      content: json['content'] as String? ?? '',
      category: cat,
      icon: ic,
      color: c,
    );
  }

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'title': title,
      'content': content,
      'category': category,
    };
  }
}
