import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../favorites/repositories/favorites_repository.dart';
import '../../../tourist_spots/repositories/review_repository.dart';
import '../../models/msme.dart';
import '../../repositories/msme_repository.dart';

final msmeFavoriteProvider =
    FutureProvider.family<bool, String>((ref, msmeUuid) async {
  final repo = ref.watch(favoritesRepositoryProvider);
  return repo.isFavorite('msme', msmeUuid);
});

class MsmeDetailPage extends ConsumerStatefulWidget {
  const MsmeDetailPage({super.key, required this.msmeId});
  final int msmeId;
  @override
  ConsumerState<MsmeDetailPage> createState() => _MsmeDetailPageState();
}

class _MsmeDetailPageState extends ConsumerState<MsmeDetailPage> {
  final _commentCtrl = TextEditingController();
  int _selectedRating = 5;
  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _call(Msme msme) async {
    if (msme.phone == null) return;
    final uri = Uri(scheme: 'tel', path: msme.phone!.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer.')));
    }
  }

  Future<void> _share(Msme msme) async {
    final shareText =
        'Check out ${msme.name} under "${msme.category}" on Tubigon Smart Tourism!\n\n"${msme.tagline}"\n\nAddress: ${msme.address}\nContact: ${msme.phone}';
    await Share.share(shareText);
  }

  Future<void> _openMap(Msme msme) async {
    if (msme.address == null) return;
    final query = Uri.encodeComponent('${msme.name}, ${msme.address}');
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps.')));
    }
  }

  void _showAddReviewDialog(Msme msme) {
    _selectedRating = 5;
    _commentCtrl.clear();
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Write a Review',
                  style: AppTypography.titleLarge
                      .copyWith(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('How was your experience with ${msme.name}?',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.grey600),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                RatingInput(
                    initialRating: _selectedRating,
                    onChanged: (val) {
                      setDialogState(() {
                        _selectedRating = val;
                      });
                    }),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  style: AppTypography.bodyMedium,
                  decoration: const InputDecoration(
                      hintText: 'Share details of your experience...',
                      border: OutlineInputBorder()),
                ),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () async {
                      final comment = _commentCtrl.text.trim();
                      if (comment.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter a comment.')));
                        return;
                      }
                      try {
                        await ref.read(reviewRepositoryProvider).addReview(
                            reviewableType: 'msme',
                            reviewableId: msme.uuid,
                            rating: _selectedRating.toDouble(),
                            content: comment);
                        ref.invalidate(
                            spotReviewsProvider(('msme', msme.uuid)));
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.success,
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.white),
                                const SizedBox(width: AppSpacing.sm),
                                Text('Review submitted successfully!',
                                    style: AppTypography.bodyMedium
                                        .copyWith(color: AppColors.white)),
                              ],
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Submission failed: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(80, 36)),
                    child: const Text('Submit')),
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final msmesAsync = ref.watch(msmeListProvider);
    return msmesAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) =>
            Scaffold(body: Center(child: Text('Error loading business: $err'))),
        data: (msmes) {
          final msme = msmes.firstWhere((m) => m.id == widget.msmeId,
              orElse: () => Msme(
                  id: 0,
                  uuid: '',
                  name: 'Not Found',
                  category: 'Handicrafts',
                  description: 'Business not found.',
                  tagline: '',
                  isVerified: false,
                  reviewCount: 0,
                  color: AppColors.primary,
                  icon: Icons.store_rounded,
                  products: [],
                  reviews: []));
          if (msme.id == 0) {
            return const Scaffold(
                body: Center(child: Text('Business details not found.')));
          }
          final isFavAsync = ref.watch(msmeFavoriteProvider(msme.uuid));
          final reviewsAsync =
              ref.watch(spotReviewsProvider(('msme', msme.uuid)));
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: AppSpacing.heroImageHeight,
                  pinned: true,
                  backgroundColor: msme.color,
                  leading: IconButton(
                      icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: AppColors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.white, size: 20)),
                      onPressed: () => context.pop()),
                  actions: [
                    isFavAsync.when(
                      data: (isFav) => IconButton(
                        icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: AppColors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle),
                            child: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isFav ? Colors.red : AppColors.white,
                                size: 20)),
                        onPressed: () async {
                          try {
                            await ref
                                .read(favoritesRepositoryProvider)
                                .toggleFavorite('msme', msme.uuid);
                            ref.invalidate(msmeFavoriteProvider(msme.uuid));
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())));
                            }
                          }
                        },
                      ),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                    IconButton(
                        icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: AppColors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.share_rounded,
                                color: AppColors.white, size: 20)),
                        onPressed: () => _share(msme)),
                    const SizedBox(width: AppSpacing.xs)
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [
                              msme.color.withValues(alpha: 0.8),
                              msme.color
                            ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)),
                        child: Stack(
                          children: [
                            Center(
                                child: Icon(msme.icon,
                                    size: 110,
                                    color: AppColors.white
                                        .withValues(alpha: 0.25))),
                            Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 60,
                                  decoration: const BoxDecoration(
                                      gradient: AppGradients.heroOverlay),
                                )),
                          ],
                        )),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: msme.color.withValues(alpha: 0.12),
                                  borderRadius: AppSpacing.roundedFull),
                              child: Text(msme.category,
                                  style: AppTypography.labelMedium.copyWith(
                                      color: msme.color,
                                      fontWeight: FontWeight.w600))),
                          const Spacer(),
                          const Icon(Icons.star_rounded,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: 4),
                          reviewsAsync.when(
                            loading: () => const SizedBox(),
                            error: (_, __) => const SizedBox(),
                            data: (revList) => Text(
                                '${msme.rating?.toStringAsFixed(1) ?? '5.0'} (${revList.length} reviews)',
                                style: AppTypography.bodySmall
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ]).animate().fadeIn(duration: 400.ms),
                        const SizedBox(height: AppSpacing.sm),
                        Text(msme.name,
                                style: AppTypography.headlineMedium
                                    .copyWith(fontWeight: FontWeight.w800))
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 100.ms),
                        const SizedBox(height: 4),
                        if (msme.tagline.isNotEmpty)
                          Text(msme.tagline,
                                  style: AppTypography.bodyMedium.copyWith(
                                      color: msme.color.withValues(alpha: 0.8),
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500))
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 150.ms),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            if (msme.phone != null &&
                                msme.phone!.isNotEmpty) ...[
                              Expanded(
                                  child: ElevatedButton.icon(
                                      onPressed: () => _call(msme),
                                      icon: const Icon(Icons.phone_rounded,
                                          size: 16),
                                      label: const Text('Call Now'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: msme.color,
                                          foregroundColor: AppColors.white,
                                          elevation: 0))),
                              const SizedBox(width: AppSpacing.sm)
                            ],
                            Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () => _openMap(msme),
                                  icon: const Icon(Icons.directions_rounded,
                                      size: 16),
                                  label: const Text('Directions'),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: msme.color,
                                      side: BorderSide(
                                          color: msme.color, width: 1.5))),
                            )
                          ],
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        Text('About the Business',
                                style: AppTypography.titleMedium
                                    .copyWith(fontWeight: FontWeight.w700))
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 250.ms),
                        const SizedBox(height: AppSpacing.sm),
                        Text(msme.description,
                                style: AppTypography.bodyMedium.copyWith(
                                    height: 1.7, color: AppColors.grey600))
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 300.ms),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: AppSpacing.roundedXl,
                              border:
                                  Border.all(color: AppColors.lightOutline)),
                          child: Column(children: [
                            if (msme.address != null &&
                                msme.address!.isNotEmpty)
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.place_outlined,
                                        size: 18, color: msme.color),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                        child: Text(msme.address!,
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                    color: AppColors.grey600)))
                                  ]),
                            if (msme.address != null &&
                                msme.businessHours != null &&
                                msme.businessHours!.isNotEmpty)
                              const Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: AppSpacing.xs),
                                  child: Divider(height: 16)),
                            if (msme.businessHours != null &&
                                msme.businessHours!.isNotEmpty)
                              Row(children: [
                                Icon(Icons.access_time_rounded,
                                    size: 18, color: msme.color),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                    child: Text(msme.businessHours!,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                                color: AppColors.grey600)))
                              ]),
                          ]),
                        ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        Text('Featured Products & Services',
                                style: AppTypography.titleMedium
                                    .copyWith(fontWeight: FontWeight.w700))
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 400.ms),
                        const SizedBox(height: AppSpacing.md),
                        if (msme.products.isEmpty)
                          Center(
                              child: Text('No products listed.',
                                  style: AppTypography.bodyMedium
                                      .copyWith(color: AppColors.grey400)))
                        else
                          ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: msme.products.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.sm),
                                  itemBuilder: (context, i) {
                                    final product = msme.products[i];
                                    return Container(
                                      padding:
                                          const EdgeInsets.all(AppSpacing.md),
                                      decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          borderRadius: AppSpacing.roundedLg,
                                          border: Border.all(
                                              color: AppColors.lightOutline)),
                                      child: Row(children: [
                                        Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                                color: msme.color
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    AppSpacing.roundedMd),
                                            child: Icon(product.icon,
                                                color: msme.color, size: 20)),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(product.name,
                                                  style: AppTypography
                                                      .bodyMedium
                                                      .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                              const SizedBox(height: 2),
                                              Text(product.description,
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                          color: AppColors
                                                              .grey500))
                                            ])),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(
                                            '₱${product.price.toStringAsFixed(0)}',
                                            style: AppTypography.labelLarge
                                                .copyWith(
                                                    color: msme.color,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                      ]),
                                    );
                                  })
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 450.ms),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Text('Reviews',
                                style: AppTypography.titleMedium
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _showAddReviewDialog(msme),
                              icon: Icon(Icons.rate_review_outlined,
                                  size: 16, color: msme.color),
                              label: Text('Write a Review',
                                  style: TextStyle(color: msme.color)),
                            )
                          ],
                        ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                        const SizedBox(height: AppSpacing.sm),
                        reviewsAsync.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (err, _) =>
                                Text('Error loading reviews: $err'),
                            data: (reviewsList) {
                              if (reviewsList.isEmpty) {
                                return Center(
                                    child: Text(
                                        'No reviews yet. Be the first to leave one!',
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                                color: AppColors.grey400)));
                              }
                              return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: reviewsList.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.sm),
                                  itemBuilder: (context, i) {
                                    final r = reviewsList[i];
                                    String dateFormatted = 'Recent';
                                    try {
                                      final dObj = DateTime.parse(r.createdAt);
                                      dateFormatted =
                                          '${dObj.month}/${dObj.day}/${dObj.year}';
                                    } catch (_) {}
                                    return Container(
                                      padding:
                                          const EdgeInsets.all(AppSpacing.md),
                                      decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          borderRadius: AppSpacing.roundedXl,
                                          border: Border.all(
                                              color: AppColors.lightOutline)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: msme.color
                                                      .withValues(alpha: 0.12),
                                                  child: Text(
                                                      r.authorName.isNotEmpty
                                                          ? r.authorName[0]
                                                              .toUpperCase()
                                                          : 'T',
                                                      style: AppTypography
                                                          .titleSmall
                                                          .copyWith(
                                                              color: msme.color,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700))),
                                              const SizedBox(
                                                  width: AppSpacing.sm),
                                              Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(r.authorName,
                                                        style: AppTypography
                                                            .bodyMedium
                                                            .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                    Text(dateFormatted,
                                                        style: AppTypography
                                                            .bodySmall
                                                            .copyWith(
                                                                color: AppColors
                                                                    .grey400))
                                                  ]),
                                              const Spacer(),
                                              RatingStars(
                                                  rating: r.rating,
                                                  starSize: 12),
                                            ]),
                                            const SizedBox(
                                                height: AppSpacing.sm),
                                            Text(r.content,
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                        color:
                                                            AppColors.grey600,
                                                        height: 1.5)),
                                          ]),
                                    );
                                  });
                            }),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }
}
