import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/exceptions/app_exception.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminReviewManagementPage extends ConsumerStatefulWidget {
  const AdminReviewManagementPage({super.key});

  @override
  ConsumerState<AdminReviewManagementPage> createState() =>
      _AdminReviewManagementPageState();
}

class _AdminReviewManagementPageState
    extends ConsumerState<AdminReviewManagementPage> {
  int _ratingFilter = 0; // 0 = All
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(adminReviewsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reviews Management',
                        style: AppTypography.headlineMedium.copyWith(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inspect tourist feedback and archive reviews when removal is authorized.',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AdminColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () => ref.invalidate(adminReviewsProvider),
                  icon: const Icon(Icons.refresh_rounded,
                      color: AdminColors.orange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Filters Bar
            Container(
              decoration: AdminColors.glassDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;
                  final search = TextField(
                    style:
                        TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Search reviews by reviewer name or comment text...',
                      hintStyle: TextStyle(color: AdminColors.textMuted),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AdminColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: AdminColors.navy900,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: AdminColors.cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: AdminColors.cardBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AdminColors.borderActive)),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  );
                  final rating = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AdminColors.navy900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        dropdownColor: AdminColors.navy900,
                        value: _ratingFilter,
                        icon: const Icon(Icons.star_outline_rounded,
                            color: Colors.amber),
                        style: TextStyle(
                            color: AdminColors.textPrimary, fontSize: 14),
                        items: const [
                          DropdownMenuItem(
                              value: 0, child: Text('All Ratings')),
                          DropdownMenuItem(
                              value: 5, child: Text('5 Stars ★★★★★')),
                          DropdownMenuItem(
                              value: 4, child: Text('4 Stars ★★★★')),
                          DropdownMenuItem(
                              value: 3, child: Text('3 Stars ★★★')),
                          DropdownMenuItem(value: 2, child: Text('2 Stars ★★')),
                          DropdownMenuItem(value: 1, child: Text('1 Star ★')),
                        ],
                        onChanged: (val) =>
                            setState(() => _ratingFilter = val!),
                      ),
                    ),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        const SizedBox(height: AppSpacing.sm),
                        rating,
                      ],
                    );
                  }
                  return Row(children: [
                    Expanded(child: search),
                    const SizedBox(width: AppSpacing.md),
                    rating,
                  ]);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Reviews Moderation Table
            Expanded(
              child: Container(
                decoration: AdminColors.glassDecoration(),
                clipBehavior: Clip.antiAlias,
                child: reviewsAsync.when(
                  data: (reviews) {
                    final filtered = reviews.where((r) {
                      final user = r['user'] is Map
                          ? Map<String, dynamic>.from(r['user'])
                          : <String, dynamic>{};
                      final reviewer =
                          (user['name'] ?? '').toString().toLowerCase();
                      final comment =
                          (r['content'] ?? '').toString().toLowerCase();
                      final rating = (r['rating'] as num?)?.toInt() ?? 0;

                      final matchesQuery =
                          reviewer.contains(_searchQuery.toLowerCase()) ||
                              comment.contains(_searchQuery.toLowerCase());
                      final matchesRating =
                          _ratingFilter == 0 || rating == _ratingFilter;
                      return matchesQuery && matchesRating;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                          child: Text('No reviews match the selected filter.',
                              style:
                                  TextStyle(color: AdminColors.textSecondary)));
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AdminColors.navy900),
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: [
                            DataColumn(
                                label: Text('REVIEWER',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('TARGET SPOT / MSME',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('RATING',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('COMMENT',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('ACTIONS',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                          ],
                          rows: filtered.map((r) {
                            final reviewId = r['id']?.toString() ??
                                r['uuid']?.toString() ??
                                '';
                            final user = r['user'] is Map
                                ? Map<String, dynamic>.from(r['user'])
                                : const <String, dynamic>{};
                            final reviewer =
                                (user['name'] ?? 'Unknown user').toString();
                            final target =
                                '${r['reviewable_type'] ?? 'item'} · ${r['reviewable_id'] ?? '—'}';
                            final rating = (r['rating'] as num?)?.toInt() ?? 0;
                            final comment = (r['content'] ?? '').toString();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AdminColors.orangeDim,
                                        child: Text(
                                          reviewer.isNotEmpty
                                              ? reviewer
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : 'R',
                                          style: const TextStyle(
                                              color: AdminColors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(reviewer,
                                          style: TextStyle(
                                              color: AdminColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(target,
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontSize: 13))),
                                DataCell(
                                  Row(
                                    children: List.generate(
                                      5,
                                      (idx) => Icon(
                                        Icons.star_rounded,
                                        color: idx < rating
                                            ? Colors.amber
                                            : AdminColors.textMuted,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 240,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          comment,
                                          style: TextStyle(
                                              color: AdminColors.textPrimary,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _adminReviewTime(r),
                                          style: TextStyle(
                                              color: AdminColors.textMuted,
                                              fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AdminColors.danger,
                                            size: 18),
                                        tooltip: 'Remove Review',
                                        onPressed: () => _confirmDeleteReview(
                                            context, reviewId),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AdminColors.orange)),
                  error: (err, _) => const Center(
                      child: Text(
                          'Unable to load reviews. Use Refresh to retry.',
                          style: TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteReview(BuildContext context, String id) async {
    const reasons = <String, String>{
      'spam': 'Spam',
      'offensive_content': 'Offensive/inappropriate content',
      'harassment': 'Harassment',
      'false_information': 'False/misleading information',
      'irrelevant_content': 'Irrelevant content',
      'privacy_information': 'Privacy/personal information',
      'duplicate': 'Duplicate',
      'community_guidelines': 'Community-guideline violation',
      'other': 'Other',
    };
    String? reason;
    final details = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final otherMissing = reason == 'other' && details.text.trim().isEmpty;
        return AlertDialog(
          title: const Text('Remove Review'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                  'Choose a moderation reason. The review owner will be notified.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Reason *'),
                items: reasons.entries
                    .map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => reason = value),
              ),
              if (reason == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  maxLength: 1000,
                  maxLines: 3,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Explanation *',
                    errorText: otherMissing ? 'Explanation is required.' : null,
                  ),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AdminColors.danger),
              onPressed: reason == null || otherMissing
                  ? null
                  : () async {
                      try {
                        await ref.read(adminRepositoryProvider).removeReview(
                              id,
                              reasonCode: reason!,
                              reasonDetail: details.text,
                            );
                        ref.invalidate(adminReviewsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _feedback('Review removed and owner notified.');
                      } catch (error) {
                        ref.invalidate(adminReviewsProvider);
                        _feedback(
                          error is ConflictException
                              ? 'This review was already updated by another session. The latest queue has been loaded.'
                              : 'Unable to remove this review.',
                          error: true,
                        );
                      }
                    },
              child: const Text('Remove Review'),
            ),
          ],
        );
      }),
    );
    details.dispose();
  }

  void _feedback(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AdminColors.danger : null,
    ));
  }
}

String _adminReviewTime(Map<String, dynamic> review) {
  String format(dynamic raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    return value == null
        ? 'Time unavailable'
        : DateFormat('MMM d, y • h:mm a').format(value);
  }

  final created = DateTime.tryParse(review['created_at']?.toString() ?? '');
  final updated = DateTime.tryParse(review['updated_at']?.toString() ?? '');
  final edited = created != null &&
      updated != null &&
      updated.difference(created).abs() > const Duration(seconds: 1);
  return edited
      ? '${format(review['created_at'])} • Edited ${format(review['updated_at'])}'
      : format(review['created_at']);
}
