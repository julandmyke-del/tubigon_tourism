import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../connected_operations/presentation/announcement_placement.dart';
import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerDashboardPage extends ConsumerWidget {
  const PartnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(partnerDashboardStatsProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _PartnerState(
            title: 'Dashboard unavailable',
            message:
                "We couldn't load your destination operations. Please try again.",
            actionLabel: 'Retry',
            action: () => ref.invalidate(partnerDashboardStatsProvider),
          ),
          data: (data) {
            final managed = (data['managedDestinations'] as List? ?? const [])
                .whereType<Map>()
                .toList(growable: false);
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(partnerDashboardStatsProvider.future),
              child: ListView(children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              managed.isEmpty
                                  ? 'Tourism Partner Dashboard'
                                  : '${managed.first['name']} Partner Portal',
                              style: PartnerTheme.headingLarge()),
                          Text(
                              managed.isEmpty
                                  ? 'Real listing and reservation activity'
                                  : 'Your assigned municipal Tourist Spot',
                              style: PartnerTheme.label()),
                        ]),
                  ],
                ),
                const AnnouncementPlacement(),
                const SizedBox(height: 20),
                if (managed.isEmpty)
                  const _PartnerState(
                    title: 'No destination assigned',
                    message:
                        'Contact the Tourism Office or wait for an Admin assignment. Destination controls will appear here after assignment.',
                    actionLabel: '',
                    action: null,
                  )
                else ...[
                  _ManagedDestinationSummary(
                    spot: Map<String, dynamic>.from(managed.first),
                    onManage: () => context.push('/tourism-partner/listings'),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth > 900
                        ? 4
                        : constraints.maxWidth > 520
                            ? 2
                            : 1;
                    final metrics = [
                      (
                        'Managed destinations',
                        data['totalManagedDestinations'] ?? managed.length,
                        Icons.place_rounded
                      ),
                      (
                        'Today reservations',
                        data['todayReservations'] ?? 0,
                        Icons.today_rounded
                      ),
                      (
                        'Pending reservations',
                        data['pendingReservations'] ?? 0,
                        Icons.pending_actions_rounded
                      ),
                      (
                        'Confirmed',
                        data['approvedReservations'] ?? 0,
                        Icons.event_available_rounded
                      ),
                      (
                        'Completed',
                        data['completedReservations'] ?? 0,
                        Icons.task_alt_rounded
                      ),
                      (
                        'Average rating',
                        data['averageRating'] ?? 0,
                        Icons.star_rounded
                      ),
                      (
                        'Total reviews',
                        data['totalReviews'] ?? 0,
                        Icons.reviews_rounded
                      ),
                    ];
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: metrics
                          .map((item) => _Metric(item.$1, item.$2, item.$3))
                          .toList(),
                    );
                  }),
                  const SizedBox(height: 20),
                  _QuickActions(spot: Map<String, dynamic>.from(managed.first)),
                  const SizedBox(height: 20),
                  Text('Needs attention', style: PartnerTheme.headingSmall()),
                  const SizedBox(height: 8),
                  if ((data['needsAttention'] as List? ?? const []).isEmpty)
                    const _Empty('No operational items need attention.')
                  else
                    ...(data['needsAttention'] as List).whereType<Map>().map(
                          (alert) => Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: const Icon(Icons.warning_amber_rounded,
                                  color: PartnerTheme.orange),
                              title: Text(
                                  '${alert['message'] ?? 'Review required'}',
                                  style: const TextStyle(color: Colors.white)),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                final route = alert['route']?.toString();
                                if (route != null &&
                                    route.startsWith('/tourism-partner')) {
                                  context.go(route);
                                }
                              },
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  Text('Recent notifications',
                      style: PartnerTheme.headingSmall()),
                  const SizedBox(height: 8),
                  if ((data['recentNotifications'] as List? ?? const [])
                      .isEmpty)
                    const _Empty('No notifications yet.')
                  else
                    ...(data['recentNotifications'] as List)
                        .whereType<Map>()
                        .map((notification) => ListTile(
                              leading: const Icon(Icons.notifications_rounded,
                                  color: PartnerTheme.primaryOrange),
                              title: Text(
                                  notification['title']?.toString() ?? 'Update',
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                  notification['body']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: PartnerTheme.textMuted)),
                            )),
                  const SizedBox(height: 20),
                  Text('Recent activity', style: PartnerTheme.headingSmall()),
                  const SizedBox(height: 8),
                  if ((data['recentActivity'] as List? ?? const []).isEmpty)
                    const _Empty('Destination activity will appear here.')
                  else
                    ...(data['recentActivity'] as List).whereType<Map>().map(
                          (activity) => Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: const Icon(Icons.history_rounded,
                                  color: PartnerTheme.primaryOrange),
                              title: Text(
                                  '${activity['action'] ?? 'Destination update'}',
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${activity['created_at'] ?? ''}',
                                  style: PartnerTheme.label()),
                            ),
                          ),
                        ),
                ],
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _ManagedDestinationSummary extends StatelessWidget {
  const _ManagedDestinationSummary({
    required this.spot,
    required this.onManage,
  });

  final Map<String, dynamic> spot;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final enabled =
        spot['booking_enabled'] == true || spot['booking_enabled'] == 1;
    final reason = (spot['booking_unavailable_reason_code']?.toString() ?? '')
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: PartnerTheme.cardDecoration(),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${spot['name'] ?? 'Assigned Destination'}',
                style: PartnerTheme.headingSmall()),
            const Text('BOOKING STATUS',
                style: TextStyle(
                    color: PartnerTheme.textMuted,
                    fontWeight: FontWeight.w800)),
            Text(enabled ? 'Accepting Reservations' : 'Temporarily Unavailable',
                style: TextStyle(
                    color: enabled ? PartnerTheme.green : PartnerTheme.red,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            if (!enabled && reason.isNotEmpty)
              Text('Reason: $reason', style: PartnerTheme.label()),
            if (spot['booking_availability_updated_at'] != null)
              Text('Last changed: ${spot['booking_availability_updated_at']}',
                  style: PartnerTheme.label()),
          ]),
          ElevatedButton.icon(
            onPressed: onManage,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Manage Availability'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final Object value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: PartnerTheme.cardDecoration(),
        child: Row(children: [
          Icon(icon, color: PartnerTheme.primaryOrange),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('$value',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(color: PartnerTheme.textMuted)),
              ])),
        ]),
      );
}

class _PartnerState extends StatelessWidget {
  const _PartnerState(
      {required this.title,
      required this.message,
      required this.actionLabel,
      required this.action});
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 100),
        const Icon(Icons.travel_explore_rounded,
            size: 60, color: PartnerTheme.primaryOrange),
        Text(title,
            textAlign: TextAlign.center, style: PartnerTheme.headingLarge()),
        Text(message, textAlign: TextAlign.center, style: PartnerTheme.label()),
        const SizedBox(height: 14),
        if (action != null)
          Center(
              child:
                  ElevatedButton(onPressed: action, child: Text(actionLabel))),
      ]);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.spot});
  final Map<String, dynamic> spot;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        ElevatedButton.icon(
            onPressed: () => context.go('/tourism-partner/listings'),
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: const Text('Manage Destination')),
        OutlinedButton.icon(
            onPressed: () => context.go('/tourism-partner/reservations'),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Reservations')),
        OutlinedButton.icon(
            onPressed: () => context.go('/tourism-partner/reviews'),
            icon: const Icon(Icons.star_outline_rounded),
            label: const Text('Reviews')),
        OutlinedButton.icon(
            onPressed: () => context.go('/tourism-partner/analytics'),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Analytics')),
        OutlinedButton.icon(
            onPressed: () =>
                context.push('/map?marker=tourist_spot:${spot['id']}'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Smart Map')),
      ]);
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: PartnerTheme.cardDecoration(),
        child: Center(
            child: Text(text,
                style: const TextStyle(color: PartnerTheme.textMuted))),
      );
}
