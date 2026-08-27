import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/lgu_providers.dart';
import '../../repositories/lgu_repository.dart';


class LguAnnouncementsPage extends ConsumerStatefulWidget {
  const LguAnnouncementsPage({super.key});

  @override
  ConsumerState<LguAnnouncementsPage> createState() => _LguAnnouncementsPageState();
}

class _LguAnnouncementsPageState extends ConsumerState<LguAnnouncementsPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  final List<Map<String, dynamic>> _announcements = [
    {'id': '1', 'title': 'Canigao Island Temporary Closure for Reef Restoration', 'category': 'Environment', 'status': 'Published', 'date': 'Aug 2, 2026', 'views': 1240},
    {'id': '2', 'title': 'Summer Tourism Festival 2026 — Tubigon Bay Celebration', 'category': 'Events', 'status': 'Published', 'date': 'Aug 1, 2026', 'views': 3820},
    {'id': '3', 'title': 'Updated Ferry Schedules for Tubigon-Cebu Route', 'category': 'Transport', 'status': 'Draft', 'date': 'Aug 3, 2026', 'views': 0},
    {'id': '4', 'title': 'New Eco-Tourism Guidelines for Marine Protected Areas', 'category': 'Environment', 'status': 'Published', 'date': 'Jul 30, 2026', 'views': 956},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyDark,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentOrange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Announcement'),
        onPressed: () => _showCreateDialog(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Municipal Announcements Board',
              style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Publish municipal news, advisories, tourism events, and official LGU communications',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _announcements.length,
              itemBuilder: (context, index) {
                final item = _announcements[index];
                final isDraft = item['status'] == 'Draft';
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: _accentOrange, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'], style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Category: ${item['category']} • ${item['date']}', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                            if (!isDraft) Text('${item['views']} views', style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDraft ? AppColors.warning.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['status'],
                          style: TextStyle(color: isDraft ? AppColors.warning : AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Create Municipal Announcement', style: TextStyle(color: AppColors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppColors.white),
                decoration: const InputDecoration(hintText: 'Title', hintStyle: TextStyle(color: AppColors.grey500)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                style: const TextStyle(color: AppColors.white),
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Content', hintStyle: TextStyle(color: AppColors.grey500)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.grey400))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentOrange),
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setState(() {
                  _announcements.insert(0, {
                    'id': '${_announcements.length + 1}',
                    'title': titleController.text,
                    'category': 'General',
                    'status': 'Published',
                    'date': 'Aug 3, 2026',
                    'views': 0,
                  });
                });
                ref.read(lguRepositoryProvider).createAnnouncement({'title': titleController.text, 'content': contentController.text});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Publish', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }
}
