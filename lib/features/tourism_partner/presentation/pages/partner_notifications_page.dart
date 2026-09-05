import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerNotificationsPage extends ConsumerStatefulWidget {
  const PartnerNotificationsPage({super.key});

  @override
  ConsumerState<PartnerNotificationsPage> createState() =>
      _PartnerNotificationsState();
}

class _PartnerNotificationsState
    extends ConsumerState<PartnerNotificationsPage> {
  String _filter = 'all';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final notifications =
        ref.watch(partnerFilteredNotificationsProvider(_filter));
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 8, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Operational Inbox', style: PartnerTheme.headingLarge()),
              Text(
                  'Reservations, reviews, municipal notices, and system updates.',
                  style: PartnerTheme.label()),
            ]),
            TextButton.icon(
              onPressed: _busy ? null : _markAll,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Mark all read'),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final value in const [
              'all',
              'unread',
              'reservations',
              'reviews',
              'municipal',
              'system'
            ])
              ChoiceChip(
                label: Text(value[0].toUpperCase() + value.substring(1)),
                selected: _filter == value,
                onSelected: (_) => setState(() => _filter = value),
              ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: notifications.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                  child: OutlinedButton(
                onPressed: () => ref
                    .invalidate(partnerFilteredNotificationsProvider(_filter)),
                child: const Text("We couldn't load notifications. Retry"),
              )),
              data: (items) => items.isEmpty
                  ? const _NotificationEmpty()
                  : RefreshIndicator(
                      onRefresh: () async => ref.refresh(
                          partnerFilteredNotificationsProvider(_filter).future),
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _NotificationRow(
                          item: items[index],
                          onTap: () => _open(items[index]),
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final repository = ref.read(tourismPartnerRepositoryProvider);
    try {
      await repository.markNotificationRead(item['id'].toString());
      if (!mounted) return;
      _refreshNotifications();
      final data = item['data'];
      final route = data is Map ? data['route']?.toString() : null;
      if (route != null &&
          (route == '/tourism-partner' ||
              route.startsWith('/tourism-partner/'))) {
        context.push(route);
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${item['title'] ?? 'Notification'}'),
            content: Text('${item['body'] ?? ''}'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) _message("We couldn't open this notification.");
    }
  }

  Future<void> _markAll() async {
    final repository = ref.read(tourismPartnerRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repository.markAllNotificationsRead();
      if (!mounted) return;
      _refreshNotifications();
    } catch (_) {
      if (mounted) _message("We couldn't update notifications.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshNotifications() {
    ref.invalidate(partnerNotificationsProvider);
    ref.invalidate(partnerFilteredNotificationsProvider);
    ref.invalidate(partnerDashboardStatsProvider);
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final unread = item['is_read'] != true && item['is_read'] != 1;
    final type = '${item['type'] ?? ''}';
    final icon = type.contains('reservation')
        ? Icons.calendar_month_outlined
        : type.contains('review')
            ? Icons.star_outline_rounded
            : type == 'announcement'
                ? Icons.campaign_outlined
                : Icons.notifications_outlined;
    return Material(
      color: unread
          ? PartnerTheme.primaryOrange.withValues(alpha: .08)
          : PartnerTheme.cardDark,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon,
            color:
                unread ? PartnerTheme.primaryOrange : PartnerTheme.textMuted),
        title: Text('${item['title'] ?? 'Update'}',
            style: TextStyle(
                color: Colors.white,
                fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
        subtitle: Text('${item['body'] ?? ''}\n${item['created_at'] ?? ''}',
            style: PartnerTheme.label()),
        isThreeLine: true,
        trailing: unread
            ? Semantics(
                label: 'Unread',
                child: const Icon(Icons.circle,
                    size: 9, color: PartnerTheme.primaryOrange))
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _NotificationEmpty extends StatelessWidget {
  const _NotificationEmpty();
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.notifications_none_rounded,
            size: 50, color: PartnerTheme.textMuted),
        const SizedBox(height: 10),
        Text("You're all caught up", style: PartnerTheme.headingSmall()),
        Text(
            'New reservations, reviews and municipal notices will appear here.',
            textAlign: TextAlign.center,
            style: PartnerTheme.label()),
      ]));
}
