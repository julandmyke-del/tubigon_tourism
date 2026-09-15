import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/auth_action_guard.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../tourist_spots/repositories/review_repository.dart';
import '../../../settings/repositories/settings_repository.dart';
import '../../../authentication/auth_provider.dart';

class PlaceReviewsPanel extends ConsumerWidget {
  const PlaceReviewsPanel({
    super.key,
    required this.reviewableType,
    required this.reviewableId,
    required this.targetName,
    this.onReviewSaved,
    this.readOnly = false,
  });

  final String reviewableType;
  final String reviewableId;
  final String targetName;
  final VoidCallback? onReviewSaved;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews =
        ref.watch(spotReviewsProvider((reviewableType, reviewableId)));
    final reviewsEnabled =
        ref.watch(systemSettingsProvider).valueOrNull?['reviews_enabled'] !=
            false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Reviews & Ratings',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!readOnly)
              TextButton(
                key: const Key('write-review-action'),
                onPressed: reviewsEnabled
                    ? () async {
                        if (await requireSignedIn(context, ref) &&
                            context.mounted) {
                          await _showReviewDialog(context, ref);
                        }
                      }
                    : null,
                child: Text(
                    reviewsEnabled ? 'Write a Review' : 'Reviews Disabled'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        reviews.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => OutlinedButton.icon(
            onPressed: () => ref.invalidate(
                spotReviewsProvider((reviewableType, reviewableId))),
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Retry reviews: $error'),
          ),
          data: (items) => items.isEmpty
              ? const _EmptyReviews()
              : Column(
                  children: items
                      .map((review) => _ReviewCard(
                            review: review,
                            owned: !readOnly &&
                                review.userId == ref.watch(authProvider).userId,
                            onEdit: () => _showReviewDialog(
                              context,
                              ref,
                              existing: review,
                            ),
                            onDelete: () => _deleteReview(context, ref, review),
                          ))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Future<void> _showReviewDialog(BuildContext context, WidgetRef ref,
      {Review? existing}) async {
    final synced = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewDialog(
        reviewableType: reviewableType,
        reviewableId: reviewableId,
        targetName: targetName,
        existing: existing,
      ),
    );
    if (synced == null || !context.mounted) return;
    ref.invalidate(spotReviewsProvider((reviewableType, reviewableId)));
    onReviewSaved?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(synced
            ? existing == null
                ? 'Review submitted successfully.'
                : 'Review updated successfully.'
            : 'Review saved offline and pending synchronization.'),
      ),
    );
  }

  Future<void> _deleteReview(
      BuildContext context, WidgetRef ref, Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content:
            const Text('This review will be removed from the public rating.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final synced =
          await ref.read(reviewRepositoryProvider).deleteReview(review);
      ref.invalidate(spotReviewsProvider((reviewableType, reviewableId)));
      onReviewSaved?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(synced
              ? 'Review deleted.'
              : 'Review deletion saved and pending synchronization.'),
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to delete the review. Please try again.')),
        );
      }
    }
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({
    required this.reviewableType,
    required this.reviewableId,
    required this.targetName,
    this.existing,
  });

  final String reviewableType;
  final String reviewableId;
  final String targetName;
  final Review? existing;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _rating = existing.rating.round();
      _commentController.text = existing.content;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _commentController.text.trim();
    if (content.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review must be between 3 and 1000 characters.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final existing = widget.existing;
      final synced = existing == null
          ? await ref.read(reviewRepositoryProvider).addReview(
                reviewableType: widget.reviewableType,
                reviewableId: widget.reviewableId,
                rating: _rating.toDouble(),
                content: content,
              )
          : await ref.read(reviewRepositoryProvider).updateReview(
                existing,
                rating: _rating.toDouble(),
                content: content,
              );
      if (mounted) Navigator.pop(context, synced);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save the review. Please try again.',
          ),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? 'Write a Review' : 'Edit Review'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How was your experience with ${widget.targetName}?'),
              const SizedBox(height: 16),
              RatingInput(
                initialRating: _rating,
                onChanged: (value) {
                  if (!_submitting) setState(() => _rating = value);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                enabled: !_submitting,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Share your experience',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.existing == null ? 'Submit' : 'Save changes'),
          ),
        ],
      );
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(
          'No reviews yet. Be the first to share your experience.',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.owned,
    required this.onEdit,
    required this.onDelete,
  });

  final Review review;
  final bool owned;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(review.authorName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (owned)
                PopupMenuButton<String>(
                  tooltip: 'Review actions',
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit review')),
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete review')),
                  ],
                ),
            ]),
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < review.rating.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 17,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(review.content),
            const SizedBox(height: 8),
            Text(
              _reviewTimestamp(review),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
}

String _reviewTimestamp(Review review) {
  String formatted(String raw) {
    final value = DateTime.tryParse(raw)?.toLocal();
    return value == null
        ? 'Time unavailable'
        : DateFormat('MMM d, y • h:mm a').format(value);
  }

  final created = formatted(review.createdAt);
  return review.isEdited
      ? '$created  •  Edited ${formatted(review.updatedAt)}'
      : created;
}
