import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class LguTouristSpotsPage extends ConsumerStatefulWidget {
  const LguTouristSpotsPage({super.key});

  @override
  ConsumerState<LguTouristSpotsPage> createState() => _LguTouristSpotsPageState();
}

class _LguTouristSpotsPageState extends ConsumerState<LguTouristSpotsPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<Map<String, dynamic>> _spots = [
    {'id': '1', 'name': 'Canigao Island', 'category': 'Beach', 'status': 'Active', 'visitors': 1240, 'rating': 4.8},
    {'id': '2', 'name': 'Tubigon Public Market', 'category': 'Market', 'status': 'Active', 'visitors': 3820, 'rating': 4.2},
    {'id': '3', 'name': 'Bohol Heritage Shrine', 'category': 'Heritage', 'status': 'Active', 'visitors': 980, 'rating': 4.6},
    {'id': '4', 'name': 'Mangrove Eco Park', 'category': 'Eco', 'status': 'Maintenance', 'visitors': 420, 'rating': 4.4},
    {'id': '5', 'name': 'Sipatan Falls', 'category': 'Nature', 'status': 'Active', 'visitors': 680, 'rating': 4.7},
    {'id': '6', 'name': 'Tubigon Wharf Port', 'category': 'Port', 'status': 'Active', 'visitors': 5100, 'rating': 4.0},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredSpots = _spots.where((spot) {
      final matchesCat = _selectedCategory == 'All' || spot['category'] == _selectedCategory;
      final matchesSearch = spot['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tourism Spot Monitoring',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Oversee active, maintenance, and capacity status of registered destinations',
                      style: TextStyle(color: AppColors.grey400, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Filter & Search Controls
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Search tourist destination...',
                      hintStyle: const TextStyle(color: AppColors.grey500),
                      prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
                      filled: true,
                      fillColor: _cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: _cardBg,
                  style: const TextStyle(color: AppColors.white),
                  items: ['All', 'Beach', 'Heritage', 'Eco', 'Nature', 'Port', 'Market']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val ?? 'All'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Spot Table Cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredSpots.length,
              itemBuilder: (context, index) {
                final item = filteredSpots[index];
                final isMaintenance = item['status'] == 'Maintenance';

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
                        child: const Icon(Icons.place_rounded, color: _accentOrange, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Category: ${item['category']}', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                                const SizedBox(width: 12),
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                Text(' ${item['rating']}', style: const TextStyle(color: AppColors.white, fontSize: 12)),
                                const SizedBox(width: 12),
                                Text('${item['visitors']} visitors/mo', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMaintenance ? AppColors.warning.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['status'],
                          style: TextStyle(
                            color: isMaintenance ? AppColors.warning : AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: AppColors.grey400),
                        onPressed: () => _showStatusDialog(context, item),
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

  void _showStatusDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Update ${item['name']} Status', style: const TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Active', style: TextStyle(color: AppColors.white)),
              onTap: () {
                setState(() => item['status'] = 'Active');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Maintenance', style: TextStyle(color: AppColors.warning)),
              onTap: () {
                setState(() => item['status'] = 'Maintenance');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Inactive', style: TextStyle(color: AppColors.error)),
              onTap: () {
                setState(() => item['status'] = 'Inactive');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
