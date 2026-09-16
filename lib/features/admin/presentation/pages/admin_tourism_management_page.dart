import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';
import '../../../map/providers/map_provider.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../../../ferry/repositories/ferry_repository.dart';
import '../../../lgupage/presentation/pages/lgu_eco_tips_page.dart';
import '../../../lgupage/presentation/pages/lgu_ferry_management_page.dart';
import '../../../lgupage/providers/lgu_providers.dart';
import '../../../../core/widgets/tourist_spot_booking_dialog.dart';

class AdminTourismManagementPage extends ConsumerStatefulWidget {
  const AdminTourismManagementPage({super.key});

  @override
  ConsumerState<AdminTourismManagementPage> createState() =>
      _AdminTourismManagementPageState();
}

class _AdminTourismManagementPageState
    extends ConsumerState<AdminTourismManagementPage>
    with SingleTickerProviderStateMixin {
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
    final emergencyAsync = ref.watch(adminEmergencyProvider);

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
                      style: AppTypography.bodyMedium
                          .copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Refresh tourism records',
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () {
                    ref.invalidate(adminSpotsProvider);
                    ref.invalidate(adminCategoriesProvider);
                    ref.invalidate(adminFerryProvider);
                    ref.invalidate(lguFerrySchedulesProvider);
                    ref.invalidate(adminEmergencyProvider);
                    ref.invalidate(adminEcoTipsProvider);
                    ref.invalidate(lguEcoTipsProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded,
                      color: AdminColors.orange),
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
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  const LguFerryManagementPage(adminMode: true),
                  // Tab 4: Emergency Contacts
                  _buildEmergencyTab(emergencyAsync),
                  // Tab 5: Eco Guidelines
                  const LguEcoTipsPage(),
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
                style: TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search tourist spots by name or location...',
                  hintStyle: TextStyle(color: AdminColors.textMuted),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AdminColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AdminColors.navy900,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AdminColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AdminColors.cardBorder)),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48)),
              onPressed: () => _showSpotDialog(context),
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text('Add Tourist Spot',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                  final name =
                      (s['name'] ?? s['title'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                      child: Text('No tourist spots found.',
                          style: TextStyle(color: AdminColors.textSecondary)));
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
                      columns: [
                        DataColumn(
                            label: Text('SPOT NAME',
                                style: TextStyle(
                                    color: AdminColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('CATEGORY / TYPE',
                                style: TextStyle(
                                    color: AdminColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('RATING',
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
                      rows: filtered.map((s) {
                        final spotId =
                            s['id']?.toString() ?? s['uuid']?.toString() ?? '';
                        final name = (s['name'] ?? s['title'] ?? 'Tourist Spot')
                            .toString();
                        final categoryData = s['category'] is Map
                            ? Map<String, dynamic>.from(s['category'])
                            : const <String, dynamic>{};
                        final category =
                            (categoryData['name'] ?? 'Uncategorized')
                                .toString();
                        final rating =
                            (s['average_rating'] as num?)?.toDouble() ?? 0;
                        final isActive =
                            (s['is_active'] == true || s['status'] == 'Active');

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                        color: AdminColors.successBg,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.landscape_rounded,
                                        color: AdminColors.success, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(name,
                                      style: TextStyle(
                                          color: AdminColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                            DataCell(Text(category,
                                style: TextStyle(
                                    color: AdminColors.textSecondary,
                                    fontSize: 13))),
                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(rating.toStringAsFixed(1),
                                      style: TextStyle(
                                          color: AdminColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AdminColors.successBg
                                      : AdminColors.warningBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'MAINTENANCE',
                                  style: TextStyle(
                                      color: isActive
                                          ? AdminColors.success
                                          : AdminColors.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            DataCell(Row(children: [
                              IconButton(
                                tooltip: (s['is_bookable'] == true ||
                                        s['is_bookable'] == 1)
                                    ? 'Booking enabled · configure'
                                    : 'Configure booking',
                                icon: Icon(
                                  Icons.event_available_rounded,
                                  color: (s['is_bookable'] == true ||
                                          s['is_bookable'] == 1)
                                      ? AdminColors.success
                                      : AdminColors.textMuted,
                                  size: 18,
                                ),
                                onPressed: () => _configureBooking(s),
                              ),
                              IconButton(
                                tooltip: 'Edit Tourist Spot',
                                icon: const Icon(Icons.edit_outlined,
                                    color: AdminColors.info, size: 18),
                                onPressed: () =>
                                    _showSpotDialog(context, existing: s),
                              ),
                              IconButton(
                                tooltip: isActive
                                    ? 'Deactivate Tourist Spot'
                                    : 'Activate Tourist Spot',
                                icon: Icon(
                                    isActive
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                    color: AdminColors.warning,
                                    size: 18),
                                onPressed: () => _setSpotActive(s, !isActive),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AdminColors.danger, size: 18),
                                tooltip: 'Archive Tourist Spot',
                                onPressed: () => _archiveSpot(spotId, name),
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
                  child: CircularProgressIndicator(color: AdminColors.orange)),
              error: (e, _) => const Center(
                  child: Text(
                      'Unable to load tourist spots. Use Refresh to retry.',
                      style: TextStyle(color: AdminColors.danger))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(AsyncValue<List<Map<String, dynamic>>> catsAsync) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Organize tourist spots with reusable categories.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AdminColors.textSecondary),
              ),
            ),
            ElevatedButton.icon(
              key: const ValueKey('add-spot-category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => _showCategoryDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Category'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Container(
            decoration: AdminColors.glassDecoration(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: catsAsync.when(
              data: (cats) {
                if (cats.isEmpty) {
                  return Center(
                    child: Text(
                      'No spot categories yet. Add one to organize listings.',
                      style: TextStyle(color: AdminColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: cats.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: AdminColors.cardBorder),
                  itemBuilder: (ctx, i) {
                    final cat = cats[i];
                    final name = (cat['name'] ?? 'Category').toString();
                    final slug = (cat['slug'] ?? '').toString();
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AdminColors.infoBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.category_outlined,
                            color: AdminColors.info),
                      ),
                      title: Text(name,
                          style: TextStyle(
                              color: AdminColors.textPrimary,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(slug.isEmpty ? 'No slug' : slug,
                          style: TextStyle(color: AdminColors.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit category',
                            onPressed: () => _showCategoryDialog(existing: cat),
                            icon: const Icon(Icons.edit_outlined,
                                color: AdminColors.info),
                          ),
                          IconButton(
                            tooltip: 'Delete category',
                            onPressed: () => _deleteCategory(cat),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AdminColors.danger),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AdminColors.orange)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load spot categories.',
                        style: TextStyle(color: AdminColors.danger)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44)),
                      onPressed: () => ref.invalidate(adminCategoriesProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCategoryDialog({Map<String, dynamic>? existing}) async {
    final formKey = GlobalKey<FormState>();
    final name =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AdminColors.navy900,
          title: Text(
            existing == null ? 'Add Spot Category' : 'Edit Spot Category',
            style: TextStyle(
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: name,
                autofocus: true,
                enabled: !saving,
                style: TextStyle(color: AdminColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'e.g. Natural Attraction',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Category name is required.'
                    : null,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      try {
                        await ref.read(adminRepositoryProvider).manageCategory(
                          {'name': name.text.trim()},
                          id: existing?['id']?.toString(),
                        );
                        _invalidateCategorySurfaces();
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        _message(existing == null
                            ? 'Spot category created.'
                            : 'Spot category updated.');
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                        _message('Unable to save this spot category.',
                            error: true);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final id = category['id']?.toString();
    if (id == null || id.isEmpty) {
      _message('This category has no valid identifier.', error: true);
      return;
    }
    final name = (category['name'] ?? 'this category').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: const Text('Delete Spot Category'),
        content: Text(
          'Delete "$name"? Categories currently assigned to tourist spots cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: AdminColors.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete Category'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteCategory(id);
      _invalidateCategorySurfaces();
      _message('Spot category deleted.');
    } catch (_) {
      _message(
        'Unable to delete this category. Reassign its tourist spots first.',
        error: true,
      );
    }
  }

  void _invalidateCategorySurfaces() {
    ref.invalidate(adminCategoriesProvider);
    ref.invalidate(adminSpotsProvider);
    ref.invalidate(spotCategoriesProvider);
    ref.invalidate(touristSpotsListProvider);
    ref.invalidate(mapMarkersProvider);
  }

  // Retained temporarily for rollback compatibility with the former Admin-only
  // form; Admin now uses the shared, stricter LGU/Admin management surface.
  // ignore: unused_element
  Widget _buildFerryTab(AsyncValue<List<Map<String, dynamic>>> ferryAsync) {
    return Column(children: [
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          onPressed: () => _showFerryDialog(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Ferry Schedule'),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Expanded(
          child: Container(
        decoration: AdminColors.glassDecoration(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ferryAsync.when(
          data: (list) => ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => Divider(color: AdminColors.cardBorder),
            itemBuilder: (ctx, i) {
              final f = list[i];
              return ListTile(
                leading: const Icon(Icons.directions_boat_rounded,
                    color: AdminColors.info),
                title: Text(f['vessel_name'] ?? f['route'] ?? 'Ferry Trip',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      (f['status'] ?? 'scheduled')
                          .toString()
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                      style: const TextStyle(
                          color: AdminColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    tooltip: 'Edit schedule',
                    onPressed: () => _showFerryDialog(existing: f),
                    icon: const Icon(Icons.edit_outlined,
                        color: AdminColors.info),
                  ),
                  IconButton(
                    tooltip: 'Archive schedule',
                    onPressed: () => _archiveFerry(f),
                    icon: const Icon(Icons.archive_outlined,
                        color: AdminColors.danger),
                  ),
                ]),
                subtitle: Text(
                    'Departure: ${f['departure_time'] ?? 'N/A'} • Fare: ₱${f['fare'] ?? '0'}',
                    style: TextStyle(color: AdminColors.textSecondary)),
              );
            },
          ),
          loading: () => const Center(
              child: CircularProgressIndicator(color: AdminColors.orange)),
          error: (_, __) => const Center(
              child: Text('Unable to load ferry schedules.',
                  style: TextStyle(color: AdminColors.danger))),
        ),
      )),
    ]);
  }

  Widget _buildEmergencyTab(
      AsyncValue<List<Map<String, dynamic>>> emergencyAsync) {
    return Column(children: [
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => context.push('/admin/emergency-contacts'),
          icon: const Icon(Icons.manage_accounts_rounded),
          label: const Text('Manage Emergency Contacts'),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Expanded(
          child: Container(
        decoration: AdminColors.glassDecoration(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: emergencyAsync.when(
          data: (list) => ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => Divider(color: AdminColors.cardBorder),
            itemBuilder: (ctx, i) {
              final e = list[i];
              return ListTile(
                leading: const Icon(Icons.phone_in_talk_rounded,
                    color: AdminColors.danger),
                title: Text(e['agency_name'] ?? e['name'] ?? 'Emergency Line',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                subtitle: Text(e['contact_number'] ?? e['phone'] ?? '',
                    style: TextStyle(color: AdminColors.textSecondary)),
              );
            },
          ),
          loading: () => const Center(
              child: CircularProgressIndicator(color: AdminColors.orange)),
          error: (e, _) => const Center(
              child: Text(
                  'Unable to load emergency contacts. Use Refresh to retry.',
                  style: TextStyle(color: AdminColors.danger))),
        ),
      )),
    ]);
  }

  // Retained temporarily for rollback compatibility with the former read-only
  // Admin view; Admin now uses the shared publish/archive management surface.
  // ignore: unused_element
  Widget _buildEcoTab(AsyncValue<List<Map<String, dynamic>>> ecoTipsAsync) {
    return Container(
      decoration: AdminColors.glassDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ecoTipsAsync.when(
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => Divider(color: AdminColors.cardBorder),
          itemBuilder: (ctx, i) {
            final tip = list[i];
            return ListTile(
              leading:
                  const Icon(Icons.eco_rounded, color: AdminColors.success),
              title: Text(tip['title'] ?? 'Eco Guideline',
                  style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.bold)),
              subtitle: Text(tip['description'] ?? tip['content'] ?? '',
                  style: TextStyle(color: AdminColors.textSecondary)),
            );
          },
        ),
        loading: () => const Center(
            child: CircularProgressIndicator(color: AdminColors.orange)),
        error: (e, _) => const Center(
            child: Text('Unable to load eco tips. Use Refresh to retry.',
                style: TextStyle(color: AdminColors.danger))),
      ),
    );
  }

  Future<void> _showFerryDialog({Map<String, dynamic>? existing}) async {
    final formKey = GlobalKey<FormState>();
    final operator =
        TextEditingController(text: existing?['operator']?.toString());
    final route = TextEditingController(text: existing?['route']?.toString());
    final departure =
        TextEditingController(text: existing?['departure_time']?.toString());
    final arrival =
        TextEditingController(text: existing?['arrival_time']?.toString());
    final fare = TextEditingController(text: existing?['fare']?.toString());
    final existingDays = existing?['days_of_week'];
    final days = TextEditingController(
        text: existingDays is List ? existingDays.join(', ') : '');
    String status = existing?['status']?.toString() ?? 'scheduled';
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminColors.navy900,
          title: Text(
              existing == null ? 'Add Ferry Schedule' : 'Edit Ferry Schedule'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _spotField(operator, 'Operator', required: true),
                  const SizedBox(height: 10),
                  _spotField(route, 'Route', required: true),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _spotField(departure, 'Departure time',
                            required: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _spotField(arrival, 'Arrival time')),
                  ]),
                  const SizedBox(height: 10),
                  _spotField(fare, 'Fare', numeric: true),
                  const SizedBox(height: 10),
                  _spotField(days, 'Operating days (comma-separated)'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    dropdownColor: AdminColors.navy900,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      'scheduled',
                      'delayed',
                      'cancelled',
                      'suspended'
                    ]
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text(value.toUpperCase())))
                        .toList(),
                    onChanged: saving ? null : (value) => status = value!,
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(adminRepositoryProvider)
                            .manageFerrySchedule({
                          'operator': operator.text.trim(),
                          'route': route.text.trim(),
                          'departure_time': departure.text.trim(),
                          'arrival_time': arrival.text.trim().isEmpty
                              ? null
                              : arrival.text.trim(),
                          'fare': double.tryParse(fare.text.trim()),
                          'status': status,
                          'days_of_week': days.text
                              .split(',')
                              .map((day) => day.trim())
                              .where((day) => day.isNotEmpty)
                              .toList(),
                        }, id: existing?['id']?.toString());
                        _invalidateFerrySurfaces();
                        if (ctx.mounted) Navigator.pop(ctx);
                        _message(existing == null
                            ? 'Ferry schedule created.'
                            : 'Ferry schedule updated.');
                      } catch (_) {
                        if (ctx.mounted) setDialogState(() => saving = false);
                        _message('Unable to save this ferry schedule.',
                            error: true);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _archiveFerry(Map<String, dynamic> ferry) async {
    final id = ferry['id']?.toString();
    if (id == null) return;
    try {
      await ref.read(adminRepositoryProvider).deleteFerrySchedule(id);
      _invalidateFerrySurfaces();
      _message('Ferry schedule archived.');
    } catch (_) {
      _message('Unable to archive this ferry schedule.', error: true);
    }
  }

  void _invalidateFerrySurfaces() {
    ref.invalidate(adminFerryProvider);
    ref.invalidate(ferrySchedulesListProvider);
  }

  Future<void> _showSpotDialog(BuildContext context,
      {Map<String, dynamic>? existing}) async {
    final categories = await ref.read(adminCategoriesProvider.future);
    if (!mounted || !context.mounted) return;

    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: existing?['name']?.toString());
    final shortDescription =
        TextEditingController(text: existing?['short_description']?.toString());
    final description =
        TextEditingController(text: existing?['description']?.toString());
    final aliases = TextEditingController(
      text: existing?['aliases'] is List
          ? (existing!['aliases'] as List).join(', ')
          : '',
    );
    final address =
        TextEditingController(text: existing?['address']?.toString());
    final latitude =
        TextEditingController(text: existing?['latitude']?.toString());
    final longitude =
        TextEditingController(text: existing?['longitude']?.toString());
    final image = TextEditingController(
      text: existing?['images'] is List &&
              (existing!['images'] as List).isNotEmpty
          ? (existing['images'] as List).first.toString()
          : '',
    );
    final categoryData = existing?['category'] is Map
        ? Map<String, dynamic>.from(existing!['category'])
        : const <String, dynamic>{};
    String? categoryId =
        existing?['category_id']?.toString() ?? categoryData['id']?.toString();
    var active = existing?['is_active'] != false;
    var published =
        existing == null ? false : existing['is_published'] != false;
    var featured = existing?['is_featured'] == true;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminColors.navy900,
          title: Text(
              existing == null ? 'Add Tourist Spot' : 'Edit Tourist Spot',
              style: TextStyle(
                  color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _spotField(name, 'Spot Name', required: true),
                    const SizedBox(height: 10),
                    _spotField(shortDescription, 'Short Description', lines: 2),
                    const SizedBox(height: 10),
                    _spotField(description, 'Full Description', lines: 4),
                    const SizedBox(height: 10),
                    _spotField(aliases, 'Search Aliases (comma-separated)'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      dropdownColor: AdminColors.navy900,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map((item) => DropdownMenuItem(
                                value: item['id']?.toString(),
                                child: Text((item['name'] ?? '').toString()),
                              ))
                          .toList(),
                      onChanged: saving ? null : (value) => categoryId = value,
                    ),
                    const SizedBox(height: 10),
                    _spotField(address, 'Address / Barangay'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child:
                              _spotField(latitude, 'Latitude', numeric: true)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _spotField(longitude, 'Longitude',
                              numeric: true)),
                      IconButton(
                        tooltip: 'Pick on map',
                        onPressed: saving
                            ? null
                            : () async {
                                final result =
                                    await context.push<Map<String, dynamic>>(
                                  '/map/pick?mode=place&lat=${latitude.text.isEmpty ? 9.9515 : latitude.text}&lng=${longitude.text.isEmpty ? 123.9618 : longitude.text}',
                                );
                                if (result != null) {
                                  setDialogState(() {
                                    latitude.text = (result['latitude'] as num?)
                                            ?.toString() ??
                                        '';
                                    longitude.text =
                                        (result['longitude'] as num?)
                                                ?.toString() ??
                                            '';
                                  });
                                }
                              },
                        icon: const Icon(Icons.add_location_alt_rounded,
                            color: AdminColors.orange),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _spotField(image, 'Primary Image URL (HTTPS)',
                        httpsUrl: true),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      title: Text('Active',
                          style: TextStyle(color: AdminColors.textPrimary)),
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => active = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: featured,
                      title: Text('Featured',
                          style: TextStyle(color: AdminColors.textPrimary)),
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => featured = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: published,
                      title: Text('Published',
                          style: TextStyle(color: AdminColors.textPrimary)),
                      subtitle: Text(
                        'Unpublished spots reject new reservations but keep booking history.',
                        style: TextStyle(color: AdminColors.textSecondary),
                      ),
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => published = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final lat = double.tryParse(latitude.text.trim());
                      final lng = double.tryParse(longitude.text.trim());
                      if ((lat == null) != (lng == null)) {
                        _message(
                            'Latitude and longitude must be supplied together.',
                            error: true);
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(adminRepositoryProvider)
                            .manageTouristSpot({
                          'name': name.text.trim(),
                          'short_description': shortDescription.text.trim(),
                          'description': description.text.trim(),
                          'aliases': aliases.text
                              .split(',')
                              .map((value) => value.trim())
                              .where((value) => value.isNotEmpty)
                              .toSet()
                              .toList(),
                          'address': address.text.trim(),
                          'category_id': categoryId,
                          'latitude': lat,
                          'longitude': lng,
                          'images': image.text.trim().isEmpty
                              ? <String>[]
                              : [image.text.trim()],
                          'is_active': active,
                          'is_published': published,
                          'is_featured': featured,
                        }, id: existing?['id']?.toString());
                        _invalidateSpotSurfaces();
                        if (ctx.mounted) Navigator.pop(ctx);
                        _message(existing == null
                            ? 'Tourist Spot created.'
                            : 'Tourist Spot updated.');
                      } catch (_) {
                        if (ctx.mounted) setDialogState(() => saving = false);
                        _message('Unable to save this Tourist Spot.',
                            error: true);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spotField(TextEditingController controller, String label,
      {bool required = false,
      int lines = 1,
      bool numeric = false,
      bool httpsUrl = false}) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType:
          numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
      style: TextStyle(color: AdminColors.textPrimary),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return '$label is required.';
        if (numeric && text.isNotEmpty && double.tryParse(text) == null) {
          return 'Enter a valid number.';
        }
        if (httpsUrl && text.isNotEmpty) {
          final uri = Uri.tryParse(text);
          if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
            return 'Enter a valid HTTPS URL.';
          }
        }
        return null;
      },
    );
  }

  Future<void> _setSpotActive(Map<String, dynamic> spot, bool active) async {
    try {
      await ref.read(adminRepositoryProvider).manageTouristSpot(
        {'is_active': active},
        id: spot['id']?.toString(),
      );
      _invalidateSpotSurfaces();
      _message(
          active ? 'Tourist Spot activated.' : 'Tourist Spot deactivated.');
    } catch (_) {
      _message('Unable to update this Tourist Spot.', error: true);
    }
  }

  Future<void> _configureBooking(Map<String, dynamic> spot) async {
    final configuration = await showTouristSpotBookingDialog(context, spot);
    if (configuration == null) return;
    try {
      await ref.read(adminRepositoryProvider).updateTouristSpotBooking(
            spot['id'].toString(),
            configuration,
          );
      _invalidateSpotSurfaces();
      ref.invalidate(adminReservationsProvider);
      _message('Booking configuration updated.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _archiveSpot(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Tourist Spot'),
        content: Text('Archive "$name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteTouristSpot(id);
      _invalidateSpotSurfaces();
      _message('Tourist Spot archived.');
    } catch (_) {
      _message('Unable to archive this Tourist Spot.', error: true);
    }
  }

  void _invalidateSpotSurfaces() {
    ref.invalidate(adminSpotsProvider);
    ref.invalidate(touristSpotsListProvider);
    ref.invalidate(bookableTouristSpotsProvider);
    ref.invalidate(mapMarkersProvider);
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? AdminColors.danger : AdminColors.success,
    ));
  }
}
