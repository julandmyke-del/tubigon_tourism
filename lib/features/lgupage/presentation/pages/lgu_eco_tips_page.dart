import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/lgu_providers.dart';
import '../../repositories/lgu_repository.dart';


class LguEcoTipsPage extends ConsumerStatefulWidget {
  const LguEcoTipsPage({super.key});

  @override
  ConsumerState<LguEcoTipsPage> createState() => _LguEcoTipsPageState();
}

class _LguEcoTipsPageState extends ConsumerState<LguEcoTipsPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  final List<Map<String, dynamic>> _ecoTips = [
    {'id': '1', 'title': 'Leave No Trace at Beach Destinations', 'category': 'Beach', 'status': 'Active', 'likes': 234},
    {'id': '2', 'title': 'Proper Waste Segregation for Tourists', 'category': 'Waste', 'status': 'Active', 'likes': 187},
    {'id': '3', 'title': 'Coral Reef Protection Guidelines', 'category': 'Marine', 'status': 'Active', 'likes': 312},
    {'id': '4', 'title': 'Mangrove Preservation Practices', 'category': 'Forest', 'status': 'Draft', 'likes': 0},
    {'id': '5', 'title': 'Sustainable Souvenir Shopping Guide', 'category': 'Commerce', 'status': 'Active', 'likes': 145},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyDark,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentOrange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Eco-Tip'),
        onPressed: () => _showCreateDialog(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eco-Tourism Tips & Guidelines',
              style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Manage environmental guidelines, sustainability tips, and conservation practices for tourists',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ecoTips.length,
              itemBuilder: (context, index) {
                final item = _ecoTips[index];
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
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.eco_rounded, color: Color(0xFF22C55E), size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'], style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Category: ${item['category']}', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                            if (!isDraft) Row(
                              children: [
                                const Icon(Icons.favorite_rounded, color: AppColors.error, size: 12),
                                const SizedBox(width: 4),
                                Text('${item['likes']} likes', style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                              ],
                            ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Add Eco-Tourism Tip', style: TextStyle(color: AppColors.white)),
        content: TextField(
          controller: titleController,
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(hintText: 'Eco-tip title', hintStyle: TextStyle(color: AppColors.grey500)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.grey400))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentOrange),
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setState(() {
                  _ecoTips.insert(0, {'id': '${_ecoTips.length + 1}', 'title': titleController.text, 'category': 'General', 'status': 'Active', 'likes': 0});
                });
                ref.read(lguRepositoryProvider).createEcoTip({'title': titleController.text});
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
