import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerNotificationsPage extends ConsumerStatefulWidget {
  const PartnerNotificationsPage({super.key});

  @override
  ConsumerState<PartnerNotificationsPage> createState() => _PartnerNotificationsPageState();
}

class _PartnerNotificationsPageState extends ConsumerState<PartnerNotificationsPage> {
  String _filter = 'all';

  final List<Map<String, dynamic>> _mockFallbackNotifications = [
    {
      'id': '1',
      'type': 'reservation',
      'title': 'New Reservation Request',
      'message': 'Maria Santos has requested a booking for Island Hopping Adventure on Aug 5, 2026 for 4 guests.',
      'time': '5 minutes ago',
      'read': false
    },
    {
      'id': '2',
      'type': 'review',
      'title': 'New 5-Star Review',
      'message': 'Juan dela Cruz left a 5-star review on your Scuba Diving Package: "Best diving experience I\'ve ever had!"',
      'time': '22 minutes ago',
      'read': false
    },
    {
      'id': '3',
      'type': 'reservation',
      'title': 'Reservation Confirmed',
      'message': 'Booking R-0059 for Ana Reyes (Dolphin Watching Trip, Aug 7) has been confirmed successfully.',
      'time': '1 hour ago',
      'read': false
    },
    {
      'id': '4',
      'type': 'payment',
      'title': 'Payment Received',
      'message': 'Payment of ₱3,200 received for Beach BBQ Experience booking R-0058. Funds will be released within 3 business days.',
      'time': '2 hours ago',
      'read': true
    },
    {
      'id': '5',
      'type': 'review',
      'title': 'New Review Posted',
      'message': 'Rosa Garcia posted a 5-star review on Snorkeling at Pandanon Island.',
      'time': '3 hours ago',
      'read': true
    },
    {
      'id': '6',
      'type': 'system',
      'title': 'Listing Approved',
      'message': 'Your listing "Bohol Day Tour Package" has been reviewed and approved. It is now visible to travelers.',
      'time': '5 hours ago',
      'read': true
    },
  ];

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(partnerNotificationsProvider);

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: notificationsAsync.when(
        data: (notifs) => _buildBody(notifs.isEmpty ? _mockFallbackNotifications : notifs),
        loading: () => const Center(child: CircularProgressIndicator(color: PartnerTheme.primaryOrange)),
        error: (_, __) => _buildBody(_mockFallbackNotifications),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> rawNotifs) {
    final unreadCount = rawNotifs.where((n) => n['read'] == false).length;

    final filtered = rawNotifs.where((n) {
      final type = (n['type'] ?? 'system').toString();
      final isRead = n['read'] == true;

      if (_filter == 'unread') return !isRead;
      if (_filter != 'all') return type == _filter;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Tabs & Mark All Read Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['all', 'unread', 'reservation', 'review', 'payment', 'system'].map((f) {
                  final isSelected = _filter == f;
                  final label = f == 'unread' ? 'Unread ($unreadCount)' : '${f[0].toUpperCase()}${f.substring(1)}';

                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = f);
                    },
                    selectedColor: PartnerTheme.primaryOrange.withValues(alpha: 0.2),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: isSelected ? PartnerTheme.primaryOrange : Colors.white.withValues(alpha: 0.08),
                    ),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? PartnerTheme.primaryOrange : PartnerTheme.textDisabled,
                    ),
                  );
                }).toList(),
              ),
              if (unreadCount > 0)
                TextButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: PartnerTheme.primaryOrange),
                  label: Text('Mark all read', style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.primaryOrange)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Notifications List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(60),
              width: double.infinity,
              decoration: PartnerTheme.cardDecoration(),
              child: Column(
                children: [
                  const Icon(Icons.notifications_off_outlined, size: 48, color: PartnerTheme.textDisabled),
                  const SizedBox(height: 12),
                  Text('No notifications', style: PartnerTheme.headingSmall()),
                  Text('You have no notifications matching this filter.', style: PartnerTheme.label()),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = filtered[index];
                return _buildNotifCard(notif);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> notif) {
    final isRead = notif['read'] == true;
    final type = (notif['type'] ?? 'system').toString();
    final id = notif['id'].toString();

    IconData icon;
    Color color;

    switch (type) {
      case 'reservation':
        icon = Icons.calendar_month_rounded;
        color = PartnerTheme.blue;
        break;
      case 'review':
        icon = Icons.star_rate_rounded;
        color = PartnerTheme.primaryOrange;
        break;
      case 'payment':
        icon = Icons.account_balance_wallet_rounded;
        color = PartnerTheme.green;
        break;
      case 'system':
      default:
        icon = Icons.settings_rounded;
        color = PartnerTheme.purple;
        break;
    }

    return InkWell(
      onTap: () => _markRead(id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: PartnerTheme.cardDecoration(
          bg: isRead ? PartnerTheme.cardDark.withValues(alpha: 0.3) : PartnerTheme.primaryOrange.withValues(alpha: 0.05),
          border: isRead ? Color(0x1AFFFFFF) : PartnerTheme.primaryOrange.withValues(alpha: 0.25),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notif['title'] ?? 'Notification',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                          color: PartnerTheme.textWhite,
                        ),
                      ),
                      Text(
                        notif['time'] ?? '',
                        style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.textDisabled),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['message'] ?? '',
                    style: GoogleFonts.inter(fontSize: 13, color: isRead ? PartnerTheme.textDisabled : PartnerTheme.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: PartnerTheme.textDisabled),
              onPressed: () => _deleteNotif(id),
            ),
          ],
        ),
      ),
    );
  }

  void _markRead(String id) async {
    try {
      final repo = ref.read(tourismPartnerRepositoryProvider);
      await repo.markNotificationRead(id);
    } catch (_) {}
    ref.invalidate(partnerNotificationsProvider);
  }

  void _markAllRead() async {
    try {
      final repo = ref.read(tourismPartnerRepositoryProvider);
      await repo.markAllNotificationsRead();
    } catch (_) {}
    ref.invalidate(partnerNotificationsProvider);
  }

  void _deleteNotif(String id) async {
    try {
      final repo = ref.read(tourismPartnerRepositoryProvider);
      await repo.deleteNotification(id);
    } catch (_) {}
    ref.invalidate(partnerNotificationsProvider);
  }
}
