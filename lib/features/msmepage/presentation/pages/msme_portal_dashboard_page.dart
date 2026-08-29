import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalDashboardPage extends ConsumerWidget {
  const MsmePortalDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(msmePortalDashboardStatsProvider);
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _StateMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Dashboard unavailable',
            message: error.toString(),
            action: () => ref.invalidate(msmePortalDashboardStatsProvider),
          ),
          data: (data) {
            final business = data['business'];
            if (business is! Map) {
              return _StateMessage(
                icon: Icons.storefront_rounded,
                title: 'Set up your business',
                message:
                    'Create your real business profile and submit it for LGU/Admin review.',
                actionLabel: 'Start business setup',
                action: () => context.push('/msme-portal/profile'),
              );
            }
            final status =
                business['verification_status']?.toString() ?? 'pending';
            final complete = <String, bool>{
              'Business profile':
                  (business['name']?.toString().isNotEmpty ?? false) &&
                      (business['category']?.toString().isNotEmpty ?? false),
              'Location':
                  business['latitude'] != null && business['longitude'] != null,
              'Contact information':
                  business['phone']?.toString().isNotEmpty ?? false,
              'Opening hours': business['opening_hours'] is Map &&
                  (business['opening_hours'] as Map).isNotEmpty,
            };
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(msmePortalDashboardStatsProvider.future),
              child: ListView(children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MSME Owner Dashboard',
                              style: MsmeTheme.headingLarge()),
                          Text(business['name']?.toString() ?? 'Business',
                              style:
                                  const TextStyle(color: MsmeTheme.textMuted)),
                        ]),
                    Wrap(spacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/map?marker=msme:${business['id']}'),
                        icon: const Icon(Icons.visibility_rounded),
                        label: Text(status == 'verified'
                            ? 'View on Smart Map'
                            : 'Private preview'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/msme-portal/profile'),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit business'),
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 18),
                _VerificationCard(
                    status: status,
                    items: complete,
                    notes: business['verification_notes']?.toString()),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 520
                          ? 2
                          : 1;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _Metric(
                          'Total reservations',
                          data['totalReservations'] ?? 0,
                          Icons.calendar_month_rounded),
                      _Metric('Pending', data['pendingReservations'] ?? 0,
                          Icons.pending_actions_rounded),
                      _Metric('Completed', data['completedReservations'] ?? 0,
                          Icons.task_alt_rounded),
                      _Metric('Average rating', data['averageRating'] ?? 0,
                          Icons.star_rounded),
                      _Metric('Reviews', data['reviewCount'] ?? 0,
                          Icons.reviews_rounded),
                    ],
                  );
                }),
                const SizedBox(height: 18),
                Text('Recent activity', style: MsmeTheme.headingSmall()),
                const SizedBox(height: 8),
                if ((data['recentActivity'] as List? ?? const []).isEmpty)
                  const _EmptyCard('No business activity yet.')
                else
                  ...(data['recentActivity'] as List)
                      .whereType<Map>()
                      .map((item) => ListTile(
                            leading: const Icon(Icons.history_rounded,
                                color: MsmeTheme.primaryOrange),
                            title: Text(
                                item['action']?.toString() ?? 'Activity',
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(item['created_at']?.toString() ?? '',
                                style: const TextStyle(
                                    color: MsmeTheme.textMuted)),
                          )),
              ]),
            );
          },
        ),
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
        decoration: MsmeTheme.cardDecoration(),
        child: Row(children: [
          Icon(icon, color: MsmeTheme.primaryOrange),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text('$value',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: MsmeTheme.textMuted)),
              ])),
        ]),
      );
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard(
      {required this.status, required this.items, this.notes});
  final String status;
  final Map<String, bool> items;
  final String? notes;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: MsmeTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Business verification', style: MsmeTheme.headingSmall()),
          const SizedBox(height: 10),
          ...items.entries.map((entry) => Row(children: [
                Icon(
                    entry.value
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: entry.value ? MsmeTheme.green : MsmeTheme.textMuted,
                    size: 18),
                const SizedBox(width: 8),
                Text(entry.key, style: const TextStyle(color: Colors.white)),
              ])),
          const Divider(),
          Text('Verification: ${status.replaceAll('_', ' ')}',
              style: const TextStyle(
                  color: MsmeTheme.primaryOrange, fontWeight: FontWeight.bold)),
          if (notes != null && notes!.isNotEmpty)
            Text(notes!, style: const TextStyle(color: MsmeTheme.amber)),
        ]),
      );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage(
      {required this.icon,
      required this.title,
      required this.message,
      required this.action,
      this.actionLabel = 'Retry'});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback action;
  final String actionLabel;
  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 100),
        Icon(icon, size: 56, color: MsmeTheme.primaryOrange),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center, style: MsmeTheme.headingLarge()),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MsmeTheme.textMuted)),
        const SizedBox(height: 16),
        Center(
            child: ElevatedButton(onPressed: action, child: Text(actionLabel))),
      ]);
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: MsmeTheme.cardDecoration(),
        child: Center(
            child:
                Text(text, style: const TextStyle(color: MsmeTheme.textMuted))),
      );
}
