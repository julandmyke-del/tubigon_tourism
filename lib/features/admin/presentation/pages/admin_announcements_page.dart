import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminAnnouncementsPage extends ConsumerStatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  ConsumerState<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends ConsumerState<AdminAnnouncementsPage> {
  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(adminAnnouncementsProvider);

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
                      'Broadcast Announcements',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Compose public bulletins, system updates, and municipal tourism notices.',
                      style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AdminColors.cardBg,
                        side: const BorderSide(color: AdminColors.cardBorder),
                      ),
                      onPressed: () => ref.invalidate(adminAnnouncementsProvider),
                      icon: const Icon(Icons.refresh_rounded, color: AdminColors.orange),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showCreateAnnouncementDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Post Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Announcements Table
            Expanded(
              child: Container(
                decoration: AdminColors.glassDecoration(),
                clipBehavior: Clip.antiAlias,
                child: announcementsAsync.when(
                  data: (announcements) {
                    if (announcements.isEmpty) {
                      return const Center(child: Text('No announcements posted yet.', style: TextStyle(color: AdminColors.textSecondary)));
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
                            DataColumn(label: Text('TITLE', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('CATEGORY', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('AUDIENCE', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('PRIORITY', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('STATUS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: announcements.map((a) {
                            final id = a['id']?.toString() ?? a['uuid']?.toString() ?? '';
                            final title = (a['title'] ?? 'Municipal Bulletin').toString();
                            final category = (a['category'] ?? 'General').toString();
                            final audience = (a['target_audience'] ?? a['audience'] ?? 'All Users').toString();
                            final priority = (a['priority'] ?? 'High').toString();
                            final status = (a['status'] ?? (a['is_active'] == true ? 'Published' : 'Draft')).toString();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(color: AdminColors.orangeDim, borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.campaign_rounded, color: AdminColors.orange, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 220,
                                        child: Text(
                                          title,
                                          style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AdminColors.infoBg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(category, style: const TextStyle(color: AdminColors.info, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Text(audience, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: priority.toLowerCase() == 'high' ? AdminColors.dangerBg : AdminColors.warningBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      priority.toUpperCase(),
                                      style: TextStyle(
                                        color: priority.toLowerCase() == 'high' ? AdminColors.danger : AdminColors.warning,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AdminColors.successBg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(status.toUpperCase(), style: const TextStyle(color: AdminColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 18),
                                    tooltip: 'Delete Announcement',
                                    onPressed: () => _confirmDelete(context, id, title),
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

  void _showCreateAnnouncementDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String category = 'Event';
    String audience = 'All Users';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('New Announcement', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: AdminColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyCtrl,
                maxLines: 3,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Content Body', labelStyle: TextStyle(color: AdminColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: AdminColors.navy900,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: AdminColors.textSecondary)),
                items: ['Event', 'Policy', 'System', 'Safety'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => category = val!,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: audience,
                dropdownColor: AdminColors.navy900,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Target Audience', labelStyle: TextStyle(color: AdminColors.textSecondary)),
                items: ['All Users', 'MSME Owners', 'Tourists'].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) => audience = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.orange),
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              final repo = ref.read(adminRepositoryProvider);
              await repo.createAnnouncement({
                'title': titleCtrl.text.trim(),
                'content': bodyCtrl.text.trim(),
                'category': category,
                'target_audience': audience,
                'is_active': true,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(adminAnnouncementsProvider);
            },
            child: const Text('Post Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('Delete Announcement', style: TextStyle(color: AdminColors.textPrimary)),
        content: Text('Are you sure you want to delete "$title"?', style: const TextStyle(color: AdminColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () async {
              final repo = ref.read(adminRepositoryProvider);
              await repo.deleteAnnouncement(id);
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(adminAnnouncementsProvider);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
