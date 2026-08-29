import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguAnnouncementsPage extends ConsumerWidget {
  const LguAnnouncementsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ReadOnlyList(
        title: 'Municipal Announcements',
        subtitle: 'Read-only for LGU staff; publication remains Admin-managed.',
        icon: Icons.campaign_rounded,
        value: ref.watch(announcementsListProvider),
        retry: () => ref.invalidate(announcementsListProvider),
      );
}

class _ReadOnlyList extends StatelessWidget {
  const _ReadOnlyList(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.value,
      required this.retry});
  final String title;
  final String subtitle;
  final IconData icon;
  final AsyncValue<List<Map<String, dynamic>>> value;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B132B),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: AppColors.grey400)),
            const SizedBox(height: 14),
            Expanded(
                child: value.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                  child: OutlinedButton(
                      onPressed: retry, child: Text('Retry: $error'))),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Text('No published content.',
                          style: TextStyle(color: AppColors.grey400)))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => ListTile(
                        tileColor: const Color(0xFF1C2541),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        leading: Icon(icon, color: AppColors.warning),
                        title: Text(
                            items[index]['title']?.toString() ??
                                'Published item',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                            items[index]['content']?.toString() ??
                                items[index]['description']?.toString() ??
                                '',
                            style: const TextStyle(color: AppColors.grey400)),
                      ),
                    ),
            )),
          ]),
        ),
      );
}
