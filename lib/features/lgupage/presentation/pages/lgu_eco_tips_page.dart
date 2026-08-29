import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguEcoTipsPage extends ConsumerWidget {
  const LguEcoTipsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  fontWeight: FontWeight.bold)),
          const Text(
              'Read-only for LGU staff; publishing remains Admin-managed.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 14),
          Expanded(
              child: tips.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton(
                    onPressed: () => ref.invalidate(lguEcoTipsProvider),
                    child: Text('Retry: $error'))),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('No eco tips published.',
                        style: TextStyle(color: AppColors.grey400)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => ListTile(
                      tileColor: const Color(0xFF1C2541),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: const Icon(Icons.eco_rounded,
                          color: AppColors.success),
                      title: Text(
                          items[index]['title']?.toString() ?? 'Eco tip',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(items[index]['content']?.toString() ?? '',
                          style: const TextStyle(color: AppColors.grey400)),
                    ),
                  ),
          )),
        ]),
      ),
    );
  }
}
