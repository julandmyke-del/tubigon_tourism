import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminReviewManagementPage extends ConsumerStatefulWidget {
  const AdminReviewManagementPage({super.key});

  @override
  ConsumerState<AdminReviewManagementPage> createState() => _AdminReviewManagementPageState();
}

class _AdminReviewManagementPageState extends ConsumerState<AdminReviewManagementPage> {
  int _ratingFilter = 0; // 0 = All
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(adminReviewsProvider);

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                      'Inspect tourist feedback, moderate reviews, and flag inappropriate comments.',
                      style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: const BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () => ref.invalidate(adminReviewsProvider),
                  icon: const Icon(Icons.refresh_rounded, color: AdminColors.orange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Filters Bar
            Container(
              decoration: AdminColors.glassDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search reviews by reviewer name or comment text...',
                        hintStyle: const TextStyle(color: AdminColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AdminColors.navy900,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.borderActive)),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
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
                        icon: const Icon(Icons.star_outline_rounded, color: Colors.amber),
                        style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('All Ratings')),
                          DropdownMenuItem(value: 5, child: Text('5 Stars ★★★★★')),
                          DropdownMenuItem(value: 4, child: Text('4 Stars ★★★★')),
                          DropdownMenuItem(value: 3, child: Text('3 Stars ★★★')),
                          DropdownMenuItem(value: 2, child: Text('2 Stars ★★')),
                          DropdownMenuItem(value: 1, child: Text('1 Star ★')),
                        ],
                        onChanged: (val) => setState(() => _ratingFilter = val!),
                      ),
                    ),
                  ),
                ],
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
                      final reviewer = (r['user_name'] ?? r['reviewer'] ?? '').toString().toLowerCase();
                      final comment = (r['comment'] ?? '').toString().toLowerCase();
                      final rating = (r['rating'] as num?)?.toInt() ?? 5;

                      final matchesQuery = reviewer.contains(_searchQuery.toLowerCase()) || comment.contains(_searchQuery.toLowerCase());
                      final matchesRating = _ratingFilter == 0 || rating == _ratingFilter;
                      return matchesQuery && matchesRating;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No reviews match the selected filter.', style: TextStyle(color: AdminColors.textSecondary)));
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AdminColors.navy900),
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('REVIEWER', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('TARGET SPOT / MSME', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('RATING', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('COMMENT', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('STATUS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: filtered.map((r) {
                            final reviewId = r['id']?.toString() ?? r['uuid']?.toString() ?? '';
                            final reviewer = (r['user_name'] ?? r['reviewer'] ?? 'Tourist').toString();
                            final target = (r['spot_name'] ?? r['target'] ?? 'Tourism Service').toString();
                            final rating = (r['rating'] as num?)?.toInt() ?? 5;
                            final comment = (r['comment'] ?? 'No comment provided.').toString();
                            final status = (r['status'] ?? 'Approved').toString();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AdminColors.orangeDim,
                                        child: Text(
                                          reviewer.isNotEmpty ? reviewer.substring(0, 1).toUpperCase() : 'R',
                                          style: const TextStyle(color: AdminColors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(reviewer, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(target, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13))),
                                DataCell(
                                  Row(
                                    children: List.generate(
                                      5,
                                      (idx) => Icon(
                                        Icons.star_rounded,
                                        color: idx < rating ? Colors.amber : AdminColors.textMuted,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 240,
                                    child: Text(
                                      comment,
                                      style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(_StatusBadge(status: status)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_outline_rounded, color: AdminColors.success, size: 18),
                                        tooltip: 'Approve Review',
                                        onPressed: () => _updateReviewStatus(context, reviewId, 'Approved'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.flag_outlined, color: AdminColors.warning, size: 18),
                                        tooltip: 'Flag Review',
                                        onPressed: () => _updateReviewStatus(context, reviewId, 'Flagged'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 18),
                                        tooltip: 'Delete Review',
                                        onPressed: () => _confirmDeleteReview(context, reviewId),
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
                  loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateReviewStatus(BuildContext context, String id, String status) async {
    final repo = ref.read(adminRepositoryProvider);
    final success = await repo.updateReviewStatus(id, status);
    if (success) ref.invalidate(adminReviewsProvider);
  }

  void _confirmDeleteReview(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('Delete Review', style: TextStyle(color: AdminColors.textPrimary)),
        content: const Text('Are you sure you want to delete this review?', style: TextStyle(color: AdminColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () async {
              final repo = ref.read(adminRepositoryProvider);
              final success = await repo.deleteReview(id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) ref.invalidate(adminReviewsProvider);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = AdminColors.successBg;
    Color fg = AdminColors.success;

    if (s == 'flagged') {
      bg = AdminColors.warningBg;
      fg = AdminColors.warning;
    } else if (s == 'deleted' || s == 'rejected') {
      bg = AdminColors.dangerBg;
      fg = AdminColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
