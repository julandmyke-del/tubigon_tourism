import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguDashboardPage extends ConsumerWidget {
  const LguDashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(lguDashboardStatsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error.toString(),
                style: const TextStyle(color: AppColors.error)),
            OutlinedButton(
                onPressed: () => ref.invalidate(lguDashboardStatsProvider),
                child: const Text('Retry')),
          ])),
          data: (data) {
            final action = data['actionCenter'] is Map
                ? data['actionCenter'] as Map
                : const {};
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(lguDashboardStatsProvider.future),
              child: ListView(children: [
                const Text('LGU Operations Dashboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const Text('Live municipal workflow counts',
                    style: TextStyle(color: AppColors.grey400)),
                const SizedBox(height: 20),
                const Text('Action Center',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _ActionCard(
                      'MSMEs awaiting review',
                      action['msmesAwaitingReview'] ?? 0,
                      Icons.storefront_rounded,
                      '/lgu/msme'),
                  _ActionCard(
                      'Emergency contacts needing verification',
                      action['emergencyContactsNeedingVerification'] ?? 0,
                      Icons.emergency_rounded,
                      '/lgu/emergency'),
                  _ActionCard(
                      'Waste reports awaiting review',
                      action['wasteReportsAwaitingReview'] ?? 0,
                      Icons.delete_outline_rounded,
                      '/lgu/waste-reports'),
                  _ActionCard(
                      'Map locations needing review',
                      action['mapLocationsNeedingReview'] ?? 0,
                      Icons.map_rounded,
                      '/lgu/map-locations'),
                ]),
                const SizedBox(height: 22),
                const Text('Municipal totals',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 520
                          ? 2
                          : 1;
                  final metrics = [
                    (
                      'Tourist spots',
                      data['totalSpots'] ?? 0,
                      Icons.place_rounded
                    ),
                    ('MSMEs', data['totalMsmes'] ?? 0, Icons.store_rounded),
                    (
                      'Active reservations',
                      data['activeReservations'] ?? 0,
                      Icons.calendar_month_rounded
                    ),
                    (
                      'Pending waste reports',
                      data['pendingWasteReports'] ?? 0,
                      Icons.pending_actions_rounded
                    ),
                    (
                      'Resolved waste reports',
                      data['resolvedWasteReports'] ?? 0,
                      Icons.task_alt_rounded
                    ),
                    (
                      'Emergency contacts',
                      data['emergencyContacts'] ?? 0,
                      Icons.call_rounded
                    ),
                  ];
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    childAspectRatio: 1.9,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: metrics
                        .map((item) => _Metric(item.$1, item.$2, item.$3))
                        .toList(),
                  );
                }),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.label, this.count, this.icon, this.route);
  final String label;
  final Object count;
  final IconData icon;
  final String route;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.go(route),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
                child: Text('$count\n$label',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: AppColors.grey400),
          ]),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final Object value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: AppColors.info),
          const SizedBox(width: 12),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$value',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: AppColors.grey400)),
              ]),
        ]),
      );
}
