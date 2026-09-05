import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguAnnouncementsPage extends ConsumerStatefulWidget {
  const LguAnnouncementsPage({super.key});
  @override
  ConsumerState<LguAnnouncementsPage> createState() => _State();
}

class _State extends ConsumerState<LguAnnouncementsPage> {
  String _query = '';
  String _status = 'all';
  String _priority = 'all';

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(announcementsListProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Municipal Announcements',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800)),
          const Text(
              'Read-only municipal advisories; publication remains Admin-managed.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
              width: 300,
              child: TextField(
                decoration: const InputDecoration(
                    labelText: 'Search announcements',
                    prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            _filter(
                'Status',
                _status,
                const ['all', 'published', 'scheduled', 'expired', 'archived'],
                (value) => setState(() => _status = value)),
            _filter(
                'Priority',
                _priority,
                const ['all', 'normal', 'important', 'urgent'],
                (value) => setState(() => _priority = value)),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: announcements.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _StateCard(
                icon: Icons.cloud_off_rounded,
                message: 'Announcements could not be loaded.\n$error',
                action: () => ref.invalidate(announcementsListProvider),
              ),
              data: (items) {
                final filtered = items.where((item) {
                  final status = item['effective_status']?.toString() ??
                      item['status']?.toString() ??
                      'published';
                  final priority = item['priority']?.toString() ?? 'normal';
                  final haystack =
                      '${item['title'] ?? ''} ${item['body'] ?? ''} ${item['type'] ?? ''}'
                          .toLowerCase();
                  return (_status == 'all' || status == _status) &&
                      (_priority == 'all' || priority == _priority) &&
                      haystack.contains(_query);
                }).toList();
                if (filtered.isEmpty) {
                  return const _StateCard(
                    icon: Icons.campaign_outlined,
                    message:
                        'No municipal announcements match this view. Published advisories for LGU Staff will appear here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(announcementsListProvider.future),
                  child: LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _AnnouncementCard(item: filtered[index]),
                      );
                    }
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 520,
                        mainAxisExtent: 245,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _AnnouncementCard(item: filtered[index]),
                    );
                  }),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _filter(String label, String value, List<String> values,
          ValueChanged<String> onChanged) =>
      SizedBox(
        width: 180,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(_label(item))))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );

  static String _label(String value) => value.isEmpty
      ? value
      : '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final priority = item['priority']?.toString() ?? 'normal';
    final status = item['effective_status']?.toString() ??
        item['status']?.toString() ??
        'published';
    final starts = DateTime.tryParse(item['starts_at']?.toString() ??
        item['published_at']?.toString() ??
        '');
    final expires = DateTime.tryParse(item['expires_at']?.toString() ?? '');
    return Material(
      color: const Color(0xFF1C2541),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text(
                      item['title']?.toString() ?? 'Municipal announcement'),
                  content: SingleChildScrollView(
                      child: Text(item['body']?.toString() ?? '')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ],
                )),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF334155))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              _Badge(
                  label: status,
                  color: status == 'published'
                      ? AppColors.success
                      : AppColors.info),
              _Badge(
                  label: priority,
                  color: priority == 'urgent'
                      ? AppColors.error
                      : priority == 'important'
                          ? AppColors.warning
                          : AppColors.info),
              _Badge(
                  label: item['audience']?.toString() ?? 'everyone',
                  color: AppColors.grey500),
            ]),
            const SizedBox(height: 12),
            Text(item['title']?.toString() ?? 'Municipal announcement',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Expanded(
                child: Text(item['body']?.toString() ?? '',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.grey400))),
            const SizedBox(height: 10),
            Text(
                'Published by ${item['publisher'] ?? 'Tubigon Administration'}',
                style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
            Text(
                '${starts == null ? 'No start date' : DateFormat('MMM d, yyyy h:mm a').format(starts.toLocal())}'
                '${expires == null ? '' : ' • expires ${DateFormat('MMM d, yyyy').format(expires.toLocal())}'}',
                style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.grey500, size: 42),
        const SizedBox(height: 10),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey400))),
        if (action != null)
          TextButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
      ]));
}
