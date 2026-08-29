import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerNotificationsPage extends ConsumerWidget {
  const PartnerNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(partnerNotificationsProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 8, children: [
            Text('Notifications', style: PartnerTheme.headingLarge()),
            TextButton.icon(
              onPressed: () => _markAll(context, ref),
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Mark all read'),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
              child: notifications.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(error.toString(),
                  style: const TextStyle(color: PartnerTheme.red)),
              OutlinedButton(
                  onPressed: () => ref.invalidate(partnerNotificationsProvider),
                  child: const Text('Retry')),
            ])),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('No notifications yet.',
                        style: TextStyle(color: PartnerTheme.textMuted)))
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(partnerNotificationsProvider.future),
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final unread =
                            item['is_read'] != true && item['is_read'] != 1;
                        return ListTile(
                          tileColor: unread
                              ? PartnerTheme.primaryOrange
                                  .withValues(alpha: .08)
                              : PartnerTheme.cardDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: Icon(
                              unread
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: unread
                                  ? PartnerTheme.primaryOrange
                                  : PartnerTheme.textMuted),
                          title: Text(item['title']?.toString() ?? 'Update',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                              '${item['body'] ?? ''}\n${item['created_at'] ?? ''}',
                              style: const TextStyle(
                                  color: PartnerTheme.textMuted)),
                          isThreeLine: true,
                          onTap: () => _open(context, ref, item),
                        );
                      },
                    ),
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
          .read(tourismPartnerRepositoryProvider)
          .markNotificationRead(item['id'].toString());
      ref.invalidate(partnerNotificationsProvider);
      final data = item['data'];
      final route = data is Map ? data['route']?.toString() : null;
      if (context.mounted &&
          route != null &&
          (route == '/tourism-partner' ||
              route.startsWith('/tourism-partner/'))) {
        context.push(route);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(tourismPartnerRepositoryProvider)
          .markAllNotificationsRead();
      ref.invalidate(partnerNotificationsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
