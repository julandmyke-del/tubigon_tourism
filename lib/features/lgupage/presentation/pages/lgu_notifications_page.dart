import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../notifications/repositories/notification_repository.dart';

class LguNotificationsPage extends ConsumerWidget {
  const LguNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(touristNotificationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(touristNotificationsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry notifications'),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(touristNotificationsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                const Expanded(
                  child: Text('Municipal Notifications',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: items.any((item) => !item.isRead)
                      ? () async {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markAllRead();
                          ref.invalidate(touristNotificationsProvider);
                          ref.invalidate(touristUnreadCountProvider);
                        }
                      : null,
                  child: const Text('Read all'),
                ),
              ]),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                      child: Text('No municipal notifications yet.',
                          style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                ...items.map((item) => Card(
                      color: const Color(0xFF1C2541),
                      child: ListTile(
                        leading: Icon(
                          item.isRead
                              ? Icons.notifications_none_rounded
                              : Icons.notifications_active_rounded,
                          color: item.isRead
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFFF97316),
                        ),
                        title: Text(item.title,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: item.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w800)),
                        subtitle: Text(item.body,
                            style: const TextStyle(color: Color(0xFFCBD5E1))),
                        onTap: () async {
                          if (!item.isRead) {
                            await ref
                                .read(notificationRepositoryProvider)
                                .markRead(item.id);
                            ref.invalidate(touristNotificationsProvider);
                            ref.invalidate(touristUnreadCountProvider);
                          }
                          if (!context.mounted) return;
                          final route = item.data['route']?.toString();
                          if (route != null &&
                              (route.startsWith('/lgu') ||
                                  route.startsWith('/map'))) {
                            context.go(route);
                          }
                        },
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
