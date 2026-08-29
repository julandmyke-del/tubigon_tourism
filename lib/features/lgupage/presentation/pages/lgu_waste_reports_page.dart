import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguWasteReportsPage extends ConsumerStatefulWidget {
  const LguWasteReportsPage({super.key});
  @override
  ConsumerState<LguWasteReportsPage> createState() => _State();
}

class _State extends ConsumerState<LguWasteReportsPage> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(lguWasteReportsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Waste Operations',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold)),
          const Text('Reporter contact details are intentionally minimized.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (final value in const [
              'all',
              'submitted',
              'under_review',
              'assigned',
              'in_progress',
              'resolved',
              'closed'
            ])
              ChoiceChip(
                  label: Text(value.replaceAll('_', ' ')),
                  selected: _filter == value,
                  onSelected: (_) => setState(() => _filter = value)),
          ]),
          const SizedBox(height: 14),
          Expanded(
              child: reports.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton(
                    onPressed: () => ref.invalidate(lguWasteReportsProvider),
                    child: Text('Retry: $error'))),
            data: (items) {
              final filtered = items.where((item) {
                final status = item['status'] == 'pending'
                    ? 'submitted'
                    : item['status']?.toString();
                return _filter == 'all' || status == _filter;
              }).toList();
              if (filtered.isEmpty) {
                return const Center(
                    child: Text('No waste reports in this view.',
                        style: TextStyle(color: AppColors.grey400)));
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(lguWasteReportsProvider.future),
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final reporter = item['user'];
                    return ListTile(
                      tileColor: const Color(0xFF1C2541),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      leading: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.warning),
                      title: Text(
                          item['category']?.toString() ?? 'Waste report',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${item['location_description'] ?? 'Pinned location'}\n${reporter is Map ? reporter['name'] ?? 'Reporter' : 'Reporter'} • ${item['status'] ?? 'submitted'} • ${item['priority'] ?? 'normal'}',
                          style: const TextStyle(color: AppColors.grey400)),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.grey400),
                      onTap: () =>
                          context.push('/lgu/waste-reports/${item['id']}'),
                    );
                  },
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
}
