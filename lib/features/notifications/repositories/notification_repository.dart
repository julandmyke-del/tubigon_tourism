import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class TouristNotification {
  const TouristNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.data = const {},
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  factory TouristNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    Map<String, dynamic> data = const {};
    if (rawData is Map) {
      data = Map<String, dynamic>.from(rawData);
    } else if (rawData is String && rawData.isNotEmpty) {
      final decoded = jsonDecode(rawData);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    }
    return TouristNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'system',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      data: data,
    );
  }
}

class NotificationRepository {
  const NotificationRepository(this._client);
  final ApiClient _client;

  Future<List<TouristNotification>> getNotifications() async {
    final response = await _client.get(ApiEndpoints.notifications);
    final items = response.data['data'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(TouristNotification.fromJson)
        .toList(growable: false);
  }

  Future<int> getUnreadCount() async {
    final response = await _client.get(ApiEndpoints.unreadCount);
    return (response.data['data']?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) => _client.put(ApiEndpoints.markRead(id));
  Future<void> markAllRead() => _client.put(ApiEndpoints.markAllRead);
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

final touristNotificationsProvider =
    FutureProvider<List<TouristNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).getNotifications();
});

final touristUnreadCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});
