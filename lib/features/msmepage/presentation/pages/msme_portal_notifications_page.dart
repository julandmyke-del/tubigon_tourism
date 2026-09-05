import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../notifications/repositories/notification_repository.dart';
import '../../../map/providers/map_provider.dart';
import '../../providers/msme_portal_providers.dart';
import '../../repositories/msme_repository.dart';
import '../msme_theme.dart';
import '../widgets/msme_portal_states.dart';

class MsmePortalNotificationsPage extends ConsumerWidget {
  const MsmePortalNotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(msmePortalNotificationsProvider);
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, children: [
            Text('Notifications', style: MsmeTheme.headingLarge()),
            TextButton.icon(
                onPressed: () => _markAll(context, ref),
                icon: const Icon(Icons.done_all),
                label: const Text('Mark all read')),
          ]),
          const SizedBox(height: 12),
          Expanded(
              child: value.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => MsmePortalErrorState(
              message: friendlyMsmeError(
                  error, 'We couldn’t load your notifications.'),
              onRetry: () => ref.invalidate(msmePortalNotificationsProvider),
            ),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('No notifications yet.',
                        style: TextStyle(color: MsmeTheme.textMuted)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final unread =
                          item['is_read'] != true && item['is_read'] != 1;
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          tileColor: unread
                              ? MsmeTheme.primaryOrange.withValues(alpha: .08)
                              : MsmeTheme.cardDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: Icon(
                              unread
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              color: MsmeTheme.primaryOrange),
                          title: Text(item['title']?.toString() ?? 'Update',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                              '${item['body'] ?? ''}\n${item['created_at'] ?? ''}',
                              style:
                                  const TextStyle(color: MsmeTheme.textMuted)),
                          isThreeLine: true,
                          onTap: () => _open(context, ref, item),
                        ),
                      );
                    },
                  ),
          )),
        ]),
      ),
    );
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    try {
      await ref
          .read(msmePortalRepositoryProvider)
          .markNotificationRead(item['id'].toString());
      if (!context.mounted) return;
      ref.invalidate(msmePortalNotificationsProvider);
      ref.invalidate(touristNotificationsProvider);
      ref.invalidate(touristUnreadCountProvider);
      if (item['type']?.toString().startsWith('msme_') == true) {
        ref.invalidate(currentMsmeProvider);
        ref.invalidate(msmePortalProfileProvider);
        ref.invalidate(msmePortalDashboardStatsProvider);
        ref.invalidate(msmePortalListingsProvider);
        ref.invalidate(msmeListProvider);
        ref.invalidate(mapMarkersProvider);
      }
      final data = item['data'];
      final route = data is Map ? data['route']?.toString() : null;
      if (context.mounted &&
          route != null &&
          (route == '/msme-portal' || route.startsWith('/msme-portal/'))) {
        context.push(route);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyMsmeError(
                error, 'We couldn’t open this notification.'))));
      }
    }
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(msmePortalRepositoryProvider).markAllNotificationsRead();
      if (!context.mounted) return;
      ref.invalidate(msmePortalNotificationsProvider);
      ref.invalidate(touristNotificationsProvider);
      ref.invalidate(touristUnreadCountProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyMsmeError(
                error, 'We couldn’t mark notifications as read.'))));
      }
    }
  }
}
