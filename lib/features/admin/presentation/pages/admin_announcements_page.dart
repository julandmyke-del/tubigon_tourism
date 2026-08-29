import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminAnnouncementsPage extends ConsumerStatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  ConsumerState<AdminAnnouncementsPage> createState() =>
      _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState
    extends ConsumerState<AdminAnnouncementsPage> {
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
                      style: AppTypography.bodyMedium
                          .copyWith(color: AdminColors.textSecondary),
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
                      onPressed: () =>
                          ref.invalidate(adminAnnouncementsProvider),
                      icon: const Icon(Icons.refresh_rounded,
                          color: AdminColors.orange),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showAnnouncementDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Post Announcement',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                      return const Center(
                          child: Text('No announcements posted yet.',
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
                          columns: const [
                            DataColumn(
                                label: Text('TITLE',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('CATEGORY',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('BODY',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('STATUS',
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
                          rows: announcements.map((a) {
                            final id = a['id']?.toString() ??
                                a['uuid']?.toString() ??
                                '';
                            final title = (a['title'] ?? '').toString();
                            final category =
                                (a['category'] ?? 'General').toString();
                            final body = (a['body'] ?? '').toString();
                            final status = a['is_active'] == true
                                ? 'Published'
                                : 'Inactive';

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                            color: AdminColors.orangeDim,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: const Icon(
                                            Icons.campaign_rounded,
                                            color: AdminColors.orange,
                                            size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 220,
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                              color: AdminColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: AdminColors.infoBg,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(category,
                                        style: const TextStyle(
                                            color: AdminColors.info,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 260,
                                    child: Text(body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AdminColors.textSecondary,
                                            fontSize: 12)),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: AdminColors.successBg,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(status.toUpperCase(),
                                        style: const TextStyle(
                                            color: AdminColors.success,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Row(children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AdminColors.info, size: 18),
                                    tooltip: 'Edit Announcement',
                                    onPressed: () => _showAnnouncementDialog(
                                        context,
                                        existing: a),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AdminColors.danger,
                                        size: 18),
                                    tooltip: 'Archive Announcement',
                                    onPressed: () =>
                                        _confirmDelete(context, id, title),
                                  ),
                                ])),
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
                          'Unable to load announcements. Use Refresh to retry.',
                          style: TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncementDialog(BuildContext context,
      {Map<String, dynamic>? existing}) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString());
    final bodyCtrl = TextEditingController(text: existing?['body']?.toString());
    String category = existing?['category']?.toString() ?? 'Event';
    bool isActive = existing?['is_active'] != false;
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
                backgroundColor: AdminColors.navy900,
                title: Text(
                    existing == null ? 'New Announcement' : 'Edit Announcement',
                    style: const TextStyle(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleCtrl,
                          style:
                              const TextStyle(color: AdminColors.textPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Title',
                              labelStyle:
                                  TextStyle(color: AdminColors.textSecondary)),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Title is required.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: bodyCtrl,
                          maxLines: 3,
                          style:
                              const TextStyle(color: AdminColors.textPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Content Body',
                              labelStyle:
                                  TextStyle(color: AdminColors.textSecondary)),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Body is required.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          dropdownColor: AdminColors.navy900,
                          style:
                              const TextStyle(color: AdminColors.textPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Category',
                              labelStyle:
                                  TextStyle(color: AdminColors.textSecondary)),
                          items: ['Event', 'Policy', 'System', 'Safety']
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) => category = val!,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          title: const Text('Publicly active',
                              style: TextStyle(color: AdminColors.textPrimary)),
                          onChanged: saving
                              ? null
                              : (value) =>
                                  setDialogState(() => isActive = value),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text('Cancel',
                        style: TextStyle(color: AdminColors.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.orange),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            setDialogState(() => saving = true);
                            try {
                              await ref
                                  .read(adminRepositoryProvider)
                                  .manageAnnouncement({
                                'title': titleCtrl.text.trim(),
                                'body': bodyCtrl.text.trim(),
                                'category': category,
                                'is_active': isActive,
                              }, id: existing?['id']?.toString());
                              ref.invalidate(adminAnnouncementsProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _message(existing == null
                                  ? 'Announcement posted.'
                                  : 'Announcement updated.');
                            } catch (_) {
                              if (ctx.mounted) {
                                setDialogState(() => saving = false);
                              }
                              _message('Unable to save the announcement.',
                                  error: true);
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(existing == null ? 'Post Now' : 'Save Changes',
                            style: const TextStyle(color: Colors.white)),
                  ),
                ],
              )),
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('Archive Announcement',
            style: TextStyle(color: AdminColors.textPrimary)),
        content: Text('Archive "$title"?',
            style: const TextStyle(color: AdminColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () async {
              try {
                await ref.read(adminRepositoryProvider).deleteAnnouncement(id);
                ref.invalidate(adminAnnouncementsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                _message('Announcement archived.');
              } catch (_) {
                _message('Unable to archive the announcement.', error: true);
              }
            },
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? AdminColors.danger : AdminColors.success,
    ));
  }
}
