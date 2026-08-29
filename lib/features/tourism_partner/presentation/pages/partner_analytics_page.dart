import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerAnalyticsPage extends ConsumerWidget {
  const PartnerAnalyticsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(partnerAnalyticsProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: analytics.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: OutlinedButton(
            onPressed: () => ref.invalidate(partnerAnalyticsProvider),
            child: Text('Retry: $error'),
          )),
          data: (data) {
            final metrics = [
              ('Reservations', data['totalReservations'] ?? 0),
              (
                'Completed',
                (data['statusDistribution'] is Map
                        ? data['statusDistribution']['completed']
                        : 0) ??
                    0
              ),
              ('Average rating', data['averageRating'] ?? 0),
              ('Reviews', data['totalReviews'] ?? 0),
            ];
            return ListView(children: [
              Text('Real Analytics', style: PartnerTheme.headingLarge()),
              Text(
                  'Only metrics calculated from reservations and reviews are shown.',
                  style: PartnerTheme.label()),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: metrics
                    .map((item) => Container(
                          width: 220,
                          padding: const EdgeInsets.all(18),
                          decoration: PartnerTheme.cardDecoration(),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.$2}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold)),
                                Text(item.$1,
                                    style: const TextStyle(
                                        color: PartnerTheme.textMuted)),
                              ]),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: PartnerTheme.cardDecoration(),
                child: Text(
                    'Most reserved listing: ${data['mostReservedListing'] ?? 'No reservations yet'}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
