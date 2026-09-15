import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';
import '../widgets/msme_portal_states.dart';

class MsmePortalListingsPage extends ConsumerWidget {
  const MsmePortalListingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentMsmeProvider);
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: current.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => MsmePortalErrorState(
          message: friendlyMsmeError(
              error, 'We couldn’t load your business listing.'),
          onRetry: () => ref.invalidate(currentMsmeProvider),
        ),
        data: (state) {
          final business = state.business;
          if (business == null) {
            return const MsmeSetupRequired(
              title: 'No business profile yet',
              message:
                  'Set up one authoritative business profile before managing its public listing.',
            );
          }
          return _ListingContent(business: business);
        },
      ),
    );
  }
}

class _ListingContent extends StatelessWidget {
  const _ListingContent({required this.business});
  final Map<String, dynamic> business;

  @override
  Widget build(BuildContext context) {
    final status = business['verification_status']?.toString() ?? 'draft';
    final verified = status == 'verified';
    final hasCoordinates =
        business['latitude'] != null && business['longitude'] != null;
    final images = (business['images'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    final updated = DateTime.tryParse(business['updated_at']?.toString() ?? '');
    final booking =
        business['booking_enabled'] == true || business['booking_enabled'] == 1;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('My Business Listing', style: MsmeTheme.headingLarge()),
        Text(
            'This is the single authoritative business record used by Tourist Explore, Smart Map, favorites, reviews, and reservations.',
            style: TextStyle(color: MsmeTheme.textMuted)),
        const SizedBox(height: 18),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: MsmeTheme.cardDecoration(),
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final cover = images.isEmpty
                ? Container(
                    color: MsmeTheme.surfaceDark,
                    child: const Center(
                        child: Icon(Icons.storefront_rounded,
                            size: 58, color: MsmeTheme.primaryOrange)))
                : Image.network(images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: MsmeTheme.surfaceDark,
                        child: const Icon(Icons.broken_image_rounded)));
            final details = Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(business['name']?.toString() ?? 'Business',
                        style: MsmeTheme.headingMedium()),
                    Text(
                        '${business['category'] ?? 'Uncategorized'} · ${business['address'] ?? 'Location not set'}',
                        style: TextStyle(color: MsmeTheme.textMuted)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      MsmeBadge(
                          label: status.replaceAll('_', ' '),
                          type: verified
                              ? MsmeBadgeType.green
                              : MsmeBadgeType.amber),
                      MsmeBadge(
                          label: verified ? 'Published' : 'Private',
                          type: verified
                              ? MsmeBadgeType.green
                              : MsmeBadgeType.gray),
                      MsmeBadge(
                          label: (business['operational_status'] ?? 'open')
                              .toString()
                              .replaceAll('_', ' ')),
                      MsmeBadge(
                          label: booking
                              ? 'Reservations enabled'
                              : 'Reservations disabled',
                          type: booking
                              ? MsmeBadgeType.blue
                              : MsmeBadgeType.gray),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                        'Rating: ${business['rating'] ?? 0} · ${business['review_count'] ?? 0} reviews',
                        style: TextStyle(color: MsmeTheme.textMuted)),
                    if (updated != null)
                      Text(
                          'Last updated ${DateFormat.yMMMd().add_jm().format(updated.toLocal())}',
                          style: TextStyle(
                              color: MsmeTheme.textDisabled, fontSize: 12)),
                    if (!verified) ...[
                      const SizedBox(height: 12),
                      const Text(
                          'Preview only — this listing is not currently visible to tourists.',
                          style: TextStyle(color: MsmeTheme.amber)),
                    ],
                    if ((business['verification_notes']?.toString() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(business['verification_notes'].toString(),
                          style: const TextStyle(color: MsmeTheme.amber)),
                    ],
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/msme-portal/profile'),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/msme-portal/preview'),
                        icon: const Icon(Icons.person_search_rounded),
                        label: const Text('Preview as Tourist'),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasCoordinates
                            ? () => context
                                .push('/map?marker=msme:${business['id']}')
                            : null,
                        icon: const Icon(Icons.map_rounded),
                        label: Text(verified
                            ? 'View on Smart Map'
                            : 'Preview Private Marker'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.go('/msme-portal/availability'),
                        icon: const Icon(Icons.edit_calendar_rounded),
                        label: const Text('Manage Availability'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/msme-portal/reviews'),
                        icon: const Icon(Icons.reviews_rounded),
                        label: const Text('View Reviews'),
                      ),
                    ]),
                  ]),
            );
            if (compact) {
              return Column(children: [
                SizedBox(height: 220, width: double.infinity, child: cover),
                details,
              ]);
            }
            return IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 310, child: cover),
                    Expanded(child: details),
                  ]),
            );
          }),
        ),
      ],
    );
  }
}
