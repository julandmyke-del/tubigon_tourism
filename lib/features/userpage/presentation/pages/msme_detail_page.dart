import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../map/map_focus.dart';
import '../../../map/providers/map_provider.dart';
import '../../../msmepage/models/msme.dart';
import '../../../msmepage/providers/msme_portal_providers.dart';
import '../../../msmepage/repositories/msme_repository.dart';
import '../widgets/place_reviews_panel.dart';

class MsmeDetailPage extends ConsumerWidget {
  const MsmeDetailPage({super.key, required this.msmeId});

  final int msmeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(msmeListProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Scaffold(
            body: _LoadFailure(
              message: 'Unable to load business details. Please try again.',
              onRetry: () => ref.invalidate(msmeListProvider),
            ),
          ),
          data: (items) {
            final matches = items.where((item) => item.id == msmeId);
            if (matches.isEmpty) {
              return const Scaffold(
                body: _LoadFailure(message: 'Business not found.'),
              );
            }
            return MsmeBusinessDetailView(
              business: matches.first,
              onReviewSaved: () => ref.invalidate(msmeListProvider),
            );
          },
        );
  }
}

/// Ownership-scoped preview. The provider calls `/msme/profile`, so an owner
/// never supplies an arbitrary business ID and their auth role is untouched.
class MsmeOwnerPreviewPage extends ConsumerWidget {
  const MsmeOwnerPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(currentMsmeProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Scaffold(
            body: _LoadFailure(
              message: 'Unable to load business preview. Please try again.',
              onRetry: () => ref.invalidate(currentMsmeProvider),
            ),
          ),
          data: (state) {
            if (state.business == null) {
              return const Scaffold(
                body: _LoadFailure(
                  message:
                      'Complete your business profile before previewing it.',
                ),
              );
            }
            return MsmeBusinessDetailView(
              business: Msme.fromJson(state.business!),
              previewMode: true,
            );
          },
        );
  }
}

/// The one tourist-facing MSME presentation used by public browsing and owner
/// preview. Preview mode preserves the visuals while suppressing mutations.
class MsmeBusinessDetailView extends StatelessWidget {
  const MsmeBusinessDetailView({
    super.key,
    required this.business,
    this.previewMode = false,
    this.onReviewSaved,
  });

  final Msme business;
  final bool previewMode;
  final VoidCallback? onReviewSaved;

  bool get _hasCoordinates =>
      business.latitude != null &&
      business.longitude != null &&
      business.latitude! >= -90 &&
      business.latitude! <= 90 &&
      business.longitude! >= -180 &&
      business.longitude! <= 180 &&
      !(business.latitude == 0 && business.longitude == 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final categoryColor = _categoryColor(business.category);
    final categoryIcon = _categoryIcon(business.category);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: previewMode ? 'Close preview' : 'Back',
          icon: Icon(
              previewMode ? Icons.close_rounded : Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(previewMode ? '/msme-portal/listings' : '/explore'),
        ),
        title: Text(previewMode ? 'Tourist Preview' : business.name),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
          vertical: 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (previewMode)
                  Material(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Icon(Icons.visibility_rounded,
                            color: colors.onTertiaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            business.isVerified
                                ? 'Preview mode — tourist actions are disabled.'
                                : 'Private preview — this listing is not published. Tourist actions are disabled.',
                            style: TextStyle(color: colors.onTertiaryContainer),
                          ),
                        ),
                      ]),
                    ),
                  ),
                if (previewMode) const SizedBox(height: 16),
                _HeroCard(
                  business: business,
                  color: categoryColor,
                  icon: categoryIcon,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final cards = [
                    _InfoCard(
                      title: 'Business Information',
                      children: [
                        _DetailRow(
                          icon: Icons.location_on_rounded,
                          label: 'Address',
                          value: business.address?.trim().isNotEmpty == true
                              ? business.address!
                              : 'Tubigon, Bohol',
                        ),
                        const Divider(),
                        _DetailRow(
                          icon: Icons.phone_rounded,
                          label: 'Contact',
                          value: business.contactNumber,
                        ),
                        if ((business.businessHours ?? '').isNotEmpty) ...[
                          const Divider(),
                          _DetailRow(
                            icon: Icons.schedule_rounded,
                            label: 'Operating information',
                            value: business.businessHours!,
                          ),
                        ],
                      ],
                    ),
                    _InfoCard(
                      title: 'About Business',
                      children: [
                        Text(
                          business.description.isNotEmpty
                              ? business.description
                              : 'Local MSME registered with Tour Tubigon.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.55),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          business.bookingEnabled
                              ? 'Online reservations are available.'
                              : 'Reservations are currently unavailable.',
                          style: TextStyle(
                            color: business.bookingEnabled
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ];
                  if (constraints.maxWidth < 720) {
                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 14),
                        cards[1]
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 14),
                      Expanded(child: cards[1]),
                    ]),
                  );
                }),
                const SizedBox(height: 24),
                if (business.isVerified && business.uuid.isNotEmpty)
                  PlaceReviewsPanel(
                    reviewableType: 'msme',
                    reviewableId: business.uuid,
                    targetName: business.name,
                    readOnly: previewMode,
                    onReviewSaved: onReviewSaved,
                  )
                else
                  _InfoCard(
                    title: 'Reviews & Ratings',
                    children: [
                      Text(
                        '${business.rating?.toStringAsFixed(1) ?? '0.0'} • ${business.reviewCount} reviews',
                      ),
                      const SizedBox(height: 6),
                      const Text(
                          'Reviews become publicly available after verification.'),
                    ],
                  ),
                const SizedBox(height: 24),
                _ActionArea(
                  business: business,
                  previewMode: previewMode,
                  hasCoordinates: _hasCoordinates,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.business, required this.color, required this.icon});
  final Msme business;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Column(children: [
        if (business.images.isNotEmpty)
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Image.network(
              business.images.first,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _ImageFallback(icon: icon, color: color),
            ),
          )
        else
          SizedBox(
              height: 180, child: _ImageFallback(icon: icon, color: color)),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: Text(
                  business.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (business.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: Color(0xFF1686C9)),
              ],
            ]),
            const SizedBox(height: 5),
            Text(business.category,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '★ ${business.rating?.toStringAsFixed(1) ?? '0.0'}  •  ${business.reviewCount} reviews',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(icon, color: color, size: 64)),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]);
}

class _ActionArea extends ConsumerWidget {
  const _ActionArea({
    required this.business,
    required this.previewMode,
    required this.hasCoordinates,
  });
  final Msme business;
  final bool previewMode;
  final bool hasCoordinates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttons = <Widget>[
      if (business.bookingEnabled)
        FilledButton.icon(
          onPressed: previewMode
              ? null
              : () => context.push(Uri(
                    path: '/reservations/create',
                    queryParameters: {
                      'type': 'msme',
                      'id': business.uuid,
                      'name': business.name,
                      'price': '0',
                    },
                  ).toString()),
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(
              previewMode ? 'Reservation disabled in preview' : 'Reserve Now'),
        ),
      if (!business.bookingEnabled)
        const OutlinedButton(
          onPressed: null,
          child: Text('Reservations currently unavailable'),
        ),
      if (business.contactNumber != 'N/A')
        OutlinedButton.icon(
          onPressed: previewMode
              ? null
              : () async {
                  final uri = Uri.parse('tel:${business.contactNumber}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
          icon: const Icon(Icons.call_rounded),
          label: const Text('Call Business'),
        ),
      OutlinedButton.icon(
        onPressed: hasCoordinates
            ? () => context.push(mapFocusPathForEntity(
                  entityType: 'msme',
                  entityId: business.uuid,
                ))
            : null,
        icon: const Icon(Icons.map_rounded),
        label: const Text('View on Smart Map'),
      ),
      OutlinedButton.icon(
        onPressed: !previewMode && hasCoordinates
            ? () => showAddToItinerarySheet(
                  context,
                  ref,
                  MapMarker(
                    id: 'msme:${business.uuid}',
                    sourceId: business.uuid,
                    sourceIntegerId: business.id,
                    name: business.name,
                    description: business.description,
                    address: business.address,
                    latitude: business.latitude!,
                    longitude: business.longitude!,
                    category: MapMarkerCategory.msme,
                    categoryName: business.category,
                    rating: business.rating,
                    reviewCount: business.reviewCount,
                    operatingHours: business.businessHours,
                    contact: business.phone,
                    isVerified: business.isVerified,
                  ),
                )
            : null,
        icon: const Icon(Icons.luggage_rounded),
        label: Text(
            previewMode ? 'Itinerary disabled in preview' : 'Add to Itinerary'),
      ),
    ];
    return Wrap(spacing: 10, runSpacing: 10, children: buttons);
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.storefront_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ]),
        ),
      );
}

Color _categoryColor(String category) {
  final key = category.toLowerCase();
  if (key.contains('food') || key.contains('restaurant')) {
    return const Color(0xFFE4572E);
  }
  if (key.contains('tour')) return const Color(0xFF1686C9);
  if (key.contains('handicraft') || key.contains('shopping')) {
    return const Color(0xFF8B5CF6);
  }
  if (key.contains('agri')) return const Color(0xFF059669);
  return const Color(0xFFF59E0B);
}

IconData _categoryIcon(String category) {
  final key = category.toLowerCase();
  if (key.contains('food') || key.contains('restaurant')) {
    return Icons.restaurant_rounded;
  }
  if (key.contains('accommodation')) return Icons.hotel_rounded;
  if (key.contains('agri')) return Icons.agriculture_rounded;
  if (key.contains('tour')) return Icons.sailing_rounded;
  return Icons.storefront_rounded;
}
