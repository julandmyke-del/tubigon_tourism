import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalAnalyticsPage extends ConsumerWidget {
  const MsmePortalAnalyticsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(msmePortalAnalyticsProvider);
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: analytics.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: OutlinedButton(
                  onPressed: () => ref.invalidate(msmePortalAnalyticsProvider),
                  child: Text('Retry: $error'))),
          data: (data) {
            final metrics = [
              (
                'Reservations',
                data['totalReservations'] ?? 0,
                Icons.calendar_month_rounded
              ),
              (
                'Pending',
                data['pendingReservations'] ?? 0,
                Icons.pending_actions_rounded
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
              ('Reviews', data['reviewCount'] ?? 0, Icons.reviews_rounded),
            ];
            return ListView(children: [
              Text('Business Analytics', style: MsmeTheme.headingLarge()),
              const Text(
                  'Only reservation and review metrics calculated from real records are shown.',
                  style: TextStyle(color: MsmeTheme.textMuted)),
              const SizedBox(height: 18),
              Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics
                      .map((item) => Container(
                            width: 230,
                            padding: const EdgeInsets.all(18),
                            decoration: MsmeTheme.cardDecoration(),
                            child: Row(children: [
                              Icon(item.$3, color: MsmeTheme.primaryOrange),
                              const SizedBox(width: 12),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${item.$2}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                    Text(item.$1,
                                        style: const TextStyle(
                                            color: MsmeTheme.textMuted)),
                                  ]),
                            ]),
                          ))
                      .toList()),
            ]);
          },
        ),
      ),
    );
  }
}
