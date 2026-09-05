import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/notification_repository.dart';
import '../../settings/repositories/settings_repository.dart';
import '../../authentication/auth_provider.dart';

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({
    super.key,
    required this.onViewAll,
    this.iconColor = const Color(0xFF94A3B8),
    this.badgeColor = const Color(0xFFF97316),
  });

  final VoidCallback onViewAll;
  final Color iconColor;
  final Color badgeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(touristNotificationsProvider);
    final items = notifications.valueOrNull ?? const <TouristNotification>[];
    final unread = items.where((item) => !item.isRead).length;

    return Builder(builder: (buttonContext) {
      return IconButton(
        tooltip: unread == 0 ? 'Notifications' : '$unread unread notifications',
        onPressed: () => _openPanel(buttonContext, ref, items),
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 99 ? '99+' : '$unread'),
          backgroundColor: badgeColor,
          child: Icon(Icons.notifications_outlined, color: iconColor),
        ),
      );
    });
  }

  Future<void> _openPanel(BuildContext context, WidgetRef ref,
      List<TouristNotification> items) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selection = await showMenu<String>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 380),
      items: [
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('Recent Notifications',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (items.isEmpty)
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('No notifications yet.'),
          )
        else
          ...items.take(5).map((item) => PopupMenuItem<String>(
                value: item.id,
                child: Semantics(
                  label:
                      '${item.isRead ? 'Read' : 'Unread'} notification: ${item.title}',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Icon(
                          item.isRead ? Icons.circle_outlined : Icons.circle,
                          size: 9,
                          color: item.isRead ? iconColor : badgeColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: item.isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold)),
                            Text(_timeAgo(item.createdAt),
                                style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__all__',
          child: Center(
              child: Text('View All',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ),
      ],
    );
    if (!context.mounted || selection == null) return;
    if (selection == '__all__') {
      onViewAll();
      return;
    }
    final item = items.where((entry) => entry.id == selection).firstOrNull;
    if (item == null) return;
    if (!item.isRead) {
      final repository = ref.read(notificationRepositoryProvider);
      await repository.markRead(item.id);
      if (!context.mounted) return;
      ref.invalidate(touristNotificationsProvider);
      ref.invalidate(touristUnreadCountProvider);
    }
    if (!context.mounted) return;
    final route = item.data['route']?.toString();
    if (item.type == 'role_application' && route?.startsWith('/') == true) {
      if (item.data['role_changed'] == true) {
        final auth = ref.read(authProvider.notifier);
        await auth.reloadProfile();
        if (!context.mounted) return;
      }
      context.go(route!);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(child: Text(item.body)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onViewAll();
            },
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime? value) {
  if (value == null) return 'Recently';
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  if (difference.inDays == 1) return 'Yesterday';
  return '${difference.inDays} days ago';
}

class AnnouncementHighlights extends ConsumerStatefulWidget {
  const AnnouncementHighlights({super.key});

  @override
  ConsumerState<AnnouncementHighlights> createState() =>
      _AnnouncementHighlightsState();
}

class _AnnouncementHighlightsState
    extends ConsumerState<AnnouncementHighlights> {
  final Set<String> _dismissedUrgent = {};

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(touristNotificationsProvider).valueOrNull ??
        const <TouristNotification>[];
    final maintenance = ref
            .watch(systemSettingsProvider)
            .valueOrNull?['maintenance_notice']
            ?.toString()
            .trim() ??
        '';
    final announcements = items
        .where((item) => item.type == 'announcement')
        .toList(growable: false);
    final urgent = announcements
        .where((item) => item.data['priority'] == 'urgent')
        .where((item) => !_dismissedUrgent.contains(item.id))
        .firstOrNull;
    final important = announcements
        .where((item) => item.data['priority'] == 'important')
        .take(2)
        .toList(growable: false);
    if (maintenance.isEmpty && urgent == null && important.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          if (maintenance.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: const Color(0xFF172554),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: Color(0xFF93C5FD)),
                  title: const Text('Tourism Office Notice',
                      style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(maintenance,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          if (urgent != null)
            Material(
              color: const Color(0xFF7F1D1D),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFCA5A5)),
                title: Text('Urgent: ${urgent.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () => _open(urgent),
                trailing: IconButton(
                  tooltip: 'Dismiss this banner for this session',
                  onPressed: () =>
                      setState(() => _dismissedUrgent.add(urgent.id)),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          if (urgent != null && important.isNotEmpty)
            const SizedBox(height: 10),
          ...important.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    leading: const Icon(Icons.campaign_rounded,
                        color: Color(0xFFF59E0B)),
                    title: const Text('Important Notice',
                        style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(item.title,
                        style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFF94A3B8)),
                    onTap: () => _open(item),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _open(TouristNotification item) async {
    if (!item.isRead) {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
      if (!mounted) return;
      ref.invalidate(touristNotificationsProvider);
      ref.invalidate(touristUnreadCountProvider);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(child: Text(item.body)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
