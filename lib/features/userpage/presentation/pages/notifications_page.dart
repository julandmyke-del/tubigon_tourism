import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../notifications/repositories/notification_repository.dart';
import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      return signedInRequiredPage(context, ref, title: 'Notifications');
    }
    final notifications = ref.watch(touristNotificationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed:
                notifications.valueOrNull?.any((item) => !item.isRead) == true
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
        ],
      ),
      body: notifications.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (error, _) => _NotificationState(
          icon: Icons.cloud_off_rounded,
          title: 'Notifications unavailable',
          message: 'Check your connection and try again.',
          action: () => ref.invalidate(touristNotificationsProvider),
        ),
        data: (items) => items.isEmpty
            ? const _NotificationState(
                icon: Icons.notifications_none_rounded,
                title: 'You are all caught up',
                message: 'Reservation and report updates will appear here.',
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(touristNotificationsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationCard(
                      notification: item,
                      onTap: () async {
                        if (!item.isRead) {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markRead(item.id);
                          ref.invalidate(touristNotificationsProvider);
                          ref.invalidate(touristUnreadCountProvider);
                        }
                        if (!context.mounted) return;
                        final reservationId =
                            item.data['reservation_id']?.toString();
                        if (reservationId != null && reservationId.isNotEmpty) {
                          context.push('/reservations/$reservationId');
                        }
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final TouristNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isReservation = notification.type.startsWith('reservation');
    final color =
        isReservation ? const Color(0xFF34D399) : const Color(0xFF38BDF8);
    final date = notification.createdAt?.toLocal();
    final time = date == null
        ? ''
        : '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      label:
          '${notification.isRead ? 'Read' : 'Unread'} notification: ${notification.title}',
      child: Material(
        color: notification.isRead
            ? const Color(0xFF0F172A)
            : color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .16),
                child: Icon(
                    isReservation
                        ? Icons.calendar_month_rounded
                        : Icons.notifications_rounded,
                    color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(notification.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700))),
                      if (!notification.isRead)
                        const CircleAvatar(
                            radius: 4, backgroundColor: Color(0xFFF59E0B)),
                    ]),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(notification.body,
                          style: const TextStyle(
                              color: Color(0xFFCBD5E1), height: 1.4)),
                    ],
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(time,
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NotificationState extends StatelessWidget {
  const _NotificationState(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: const Color(0xFF64748B)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8))),
          if (action != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry')),
          ],
        ]),
      ));
}
