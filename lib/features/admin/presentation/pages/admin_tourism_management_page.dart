import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminTourismManagementPage extends ConsumerStatefulWidget {
  const AdminTourismManagementPage({super.key});

  @override
  ConsumerState<AdminTourismManagementPage> createState() => _AdminTourismManagementPageState();
}

class _AdminTourismManagementPageState extends ConsumerState<AdminTourismManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spotsAsync = ref.watch(adminSpotsProvider);
    final catsAsync = ref.watch(adminCategoriesProvider);
    final ferryAsync = ref.watch(adminFerryProvider);
    final emergencyAsync = ref.watch(adminEmergencyProvider);
    final ecoTipsAsync = ref.watch(adminEcoTipsProvider);

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
                      'Tourism Management',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage municipal tourist spots, categories, ferry vessel schedules, and eco guidelines.',
                      style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: const BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () {
                    ref.invalidate(adminSpotsProvider);
                    ref.invalidate(adminCategoriesProvider);
                    ref.invalidate(adminFerryProvider);
                    ref.invalidate(adminEmergencyProvider);
                    ref.invalidate(adminEcoTipsProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded, color: AdminColors.orange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: AdminColors.navy900,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminColors.cardBorder),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AdminColors.orange,
                indicatorWeight: 3,
                labelColor: AdminColors.orange,
                unselectedLabelColor: AdminColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Tourist Spots'),
                  Tab(text: 'Spot Categories'),
                  Tab(text: 'Ferry Schedules'),
                  Tab(text: 'Emergency Contacts'),
                  Tab(text: 'Eco Guidelines'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Tab Content Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Tourist Spots
                  _buildSpotsTab(spotsAsync),
                  // Tab 2: Categories
                  _buildCategoriesTab(catsAsync),
                  // Tab 3: Ferry Schedules
                  _buildFerryTab(ferryAsync),
                  // Tab 4: Emergency Contacts
                  _buildEmergencyTab(emergencyAsync),
                  // Tab 5: Eco Guidelines
                  _buildEcoTab(ecoTipsAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotsTab(AsyncValue<List<Map<String, dynamic>>> spotsAsync) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search tourist spots by name or location...',
                  hintStyle: const TextStyle(color: AdminColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AdminColors.navy900,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.orange, foregroundColor: Colors.white),
              onPressed: () => _showAddSpotDialog(context),
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text('Add Tourist Spot', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Container(
            decoration: AdminColors.glassDecoration(),
            clipBehavior: Clip.antiAlias,
            child: spotsAsync.when(
              data: (spots) {
                final filtered = spots.where((s) {
                  final name = (s['name'] ?? s['title'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No tourist spots found.', style: TextStyle(color: AdminColors.textSecondary)));
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
                        DataColumn(label: Text('SPOT NAME', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('CATEGORY / TYPE', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('RATING', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('STATUS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('ACTIONS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                      rows: filtered.map((s) {
                        final spotId = s['id']?.toString() ?? s['uuid']?.toString() ?? '';
                        final name = (s['name'] ?? s['title'] ?? 'Tourist Spot').toString();
                        final category = (s['category_name'] ?? s['category'] ?? s['type'] ?? 'Natural Wonder').toString();
                        final rating = double.tryParse((s['average_rating'] ?? s['rating'] ?? '4.7').toString()) ?? 4.7;
                        final isActive = (s['is_active'] == true || s['status'] == 'Active');

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(color: AdminColors.successBg, borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.landscape_rounded, color: AdminColors.success, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(name, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            ),
                            DataCell(Text(category, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13))),
                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(rating.toStringAsFixed(1), style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive ? AdminColors.successBg : AdminColors.warningBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'MAINTENANCE',
                                  style: TextStyle(color: isActive ? AdminColors.success : AdminColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 18),
                                onPressed: () async {
                                  final repo = ref.read(adminRepositoryProvider);
                                  await repo.deleteTouristSpot(spotId);
                                  ref.invalidate(adminSpotsProvider);
                                },
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
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(AsyncValue<List<Map<String, dynamic>>> catsAsync) {
    return Container(
      decoration: AdminColors.glassDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: catsAsync.when(
        data: (cats) => ListView.separated(
          itemCount: cats.length,
          separatorBuilder: (_, __) => const Divider(color: AdminColors.cardBorder),
          itemBuilder: (ctx, i) {
            final cat = cats[i];
            return ListTile(
              title: Text(cat['name'] ?? 'Category', style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(cat['description'] ?? cat['slug'] ?? '', style: const TextStyle(color: AdminColors.textSecondary)),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger))),
      ),
    );
  }

  Widget _buildFerryTab(AsyncValue<List<Map<String, dynamic>>> ferryAsync) {
    return Container(
      decoration: AdminColors.glassDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ferryAsync.when(
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: AdminColors.cardBorder),
          itemBuilder: (ctx, i) {
            final f = list[i];
            return ListTile(
              leading: const Icon(Icons.directions_boat_rounded, color: AdminColors.info),
              title: Text(f['vessel_name'] ?? f['route'] ?? 'Ferry Trip', style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text('Departure: ${f['departure_time'] ?? 'N/A'} • Fare: ₱${f['fare'] ?? '0'}', style: const TextStyle(color: AdminColors.textSecondary)),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger))),
      ),
    );
  }

  Widget _buildEmergencyTab(AsyncValue<List<Map<String, dynamic>>> emergencyAsync) {
    return Container(
      decoration: AdminColors.glassDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: emergencyAsync.when(
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: AdminColors.cardBorder),
          itemBuilder: (ctx, i) {
            final e = list[i];
            return ListTile(
              leading: const Icon(Icons.phone_in_talk_rounded, color: AdminColors.danger),
              title: Text(e['agency_name'] ?? e['name'] ?? 'Emergency Line', style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(e['contact_number'] ?? e['phone'] ?? '', style: const TextStyle(color: AdminColors.textSecondary)),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger))),
      ),
    );
  }

  Widget _buildEcoTab(AsyncValue<List<Map<String, dynamic>>> ecoTipsAsync) {
    return Container(
      decoration: AdminColors.glassDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ecoTipsAsync.when(
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: AdminColors.cardBorder),
          itemBuilder: (ctx, i) {
            final tip = list[i];
            return ListTile(
              leading: const Icon(Icons.eco_rounded, color: AdminColors.success),
              title: Text(tip['title'] ?? 'Eco Guideline', style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(tip['description'] ?? tip['content'] ?? '', style: const TextStyle(color: AdminColors.textSecondary)),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger))),
      ),
    );
  }

  void _showAddSpotDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('Add New Tourist Spot', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Spot Name', labelStyle: TextStyle(color: AdminColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AdminColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                style: const TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Address / Barangay', labelStyle: TextStyle(color: AdminColors.textSecondary)),
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
              if (nameCtrl.text.isEmpty) return;
              final repo = ref.read(adminRepositoryProvider);
              await repo.createTouristSpot({
                'name': nameCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'address': addrCtrl.text.trim(),
                'is_active': true,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(adminSpotsProvider);
            },
            child: const Text('Add Spot', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
