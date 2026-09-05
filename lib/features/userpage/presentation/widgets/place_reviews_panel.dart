import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/auth_action_guard.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../tourist_spots/repositories/review_repository.dart';
import '../../../settings/repositories/settings_repository.dart';

class PlaceReviewsPanel extends ConsumerWidget {
  const PlaceReviewsPanel({
    super.key,
    required this.reviewableType,
    required this.reviewableId,
    required this.targetName,
    this.onReviewSaved,
  });

  final String reviewableType;
  final String reviewableId;
  final String targetName;
  final VoidCallback? onReviewSaved;

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
            const Expanded(
              child: Text(
                'Reviews & Ratings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
              child:
                  Text(reviewsEnabled ? 'Write a Review' : 'Reviews Disabled'),
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
                      .map((review) => _ReviewCard(review: review))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Future<void> _showReviewDialog(BuildContext context, WidgetRef ref) async {
    final synced = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewDialog(
        reviewableType: reviewableType,
        reviewableId: reviewableId,
        targetName: targetName,
      ),
    );
    if (synced == null || !context.mounted) return;
    ref.invalidate(spotReviewsProvider((reviewableType, reviewableId)));
    onReviewSaved?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(synced
            ? 'Review submitted successfully.'
            : 'Review saved offline and pending synchronization.'),
      ),
    );
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({
    required this.reviewableType,
    required this.reviewableId,
    required this.targetName,
  });

  final String reviewableType;
  final String reviewableId;
  final String targetName;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

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
      final synced = await ref.read(reviewRepositoryProvider).addReview(
            reviewableType: widget.reviewableType,
            reviewableId: widget.reviewableId,
            rating: _rating.toDouble(),
            content: content,
          );
      if (mounted) Navigator.pop(context, synced);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Submission failed: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Write a Review'),
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
                : const Text('Submit'),
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
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: const Text(
          'No reviews yet. Be the first to share your experience.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(review.authorName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
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
            Text(review.content,
                style: const TextStyle(color: Color(0xFFCBD5E1))),
          ],
        ),
      );
}
