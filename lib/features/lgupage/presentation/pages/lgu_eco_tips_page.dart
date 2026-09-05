import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguEcoTipsPage extends ConsumerStatefulWidget {
  const LguEcoTipsPage({super.key});
  @override
  ConsumerState<LguEcoTipsPage> createState() => _State();
}

class _State extends ConsumerState<LguEcoTipsPage> {
  String _query = '';
  String _category = 'all';
  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(lguEcoTipsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Eco-Tourism Tips',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800)),
          const Text(
              'Read-only environmental guidance; publishing remains Admin-managed.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 14),
          Expanded(
              child: tips.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton.icon(
                    onPressed: () => ref.invalidate(lguEcoTipsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text('Retry: $error'))),
            data: (items) {
              final categories = items
                  .map((item) => item['category']?.toString() ?? 'general')
                  .toSet()
                  .toList()
                ..sort();
              final filtered = items.where((item) {
                final category = item['category']?.toString() ?? 'general';
                final haystack =
                    '${item['title'] ?? ''} ${item['content'] ?? ''}'
                        .toLowerCase();
                return (_category == 'all' || category == _category) &&
                    haystack.contains(_query);
              }).toList();
              return Column(children: [
                Wrap(spacing: 10, runSpacing: 10, children: [
                  SizedBox(
                      width: 300,
                      child: TextField(
                        decoration: const InputDecoration(
                            labelText: 'Search eco-tips',
                            prefixIcon: Icon(Icons.search_rounded)),
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      )),
                  SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            categories.contains(_category) || _category == 'all'
                                ? _category
                                : 'all',
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: ['all', ...categories]
                            .map((item) => DropdownMenuItem(
                                value: item, child: Text(_label(item))))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _category = value ?? 'all'),
                      )),
                ]),
                const SizedBox(height: 14),
                Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No eco-tips match this view.',
                                style: TextStyle(color: AppColors.grey400)))
                        : RefreshIndicator(
                            onRefresh: () =>
                                ref.refresh(lguEcoTipsProvider.future),
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 500,
                                      mainAxisExtent: 190,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return Container(
                                  padding: const EdgeInsets.all(17),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF1C2541),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: const Color(0xFF334155))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.eco_rounded,
                                              color: AppColors.success),
                                          const SizedBox(width: 8),
                                          Text(
                                              _label(item['category']
                                                      ?.toString() ??
                                                  'general'),
                                              style: const TextStyle(
                                                  color: AppColors.success,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700)),
                                        ]),
                                        const SizedBox(height: 10),
                                        Text(
                                            item['title']?.toString() ??
                                                'Eco tip',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 6),
                                        Expanded(
                                            child: Text(
                                                item['content']?.toString() ??
                                                    '',
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: AppColors.grey400))),
                                      ]),
                                );
                              },
                            ),
                          )),
              ]);
            },
          )),
        ]),
      ),
    );
  }

  static String _label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
