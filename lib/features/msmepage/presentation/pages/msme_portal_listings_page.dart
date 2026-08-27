import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalListingsPage extends ConsumerStatefulWidget {
  const MsmePortalListingsPage({super.key});

  @override
  ConsumerState<MsmePortalListingsPage> createState() =>
      _MsmePortalListingsPageState();
}

class _MsmePortalListingsPageState
    extends ConsumerState<MsmePortalListingsPage> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(msmePortalListingsProvider);

    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Business Listings',
                        style: MsmeTheme.headingLarge()),
                    Text(
                        'Manage products, dining menus, tour packages, and pricing.',
                        style: MsmeTheme.body(color: MsmeTheme.textMuted)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MsmeTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => context.go('/msme-portal/listings/create'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add New Listing',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              decoration: MsmeTheme.cardDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.inter(
                          color: MsmeTheme.textWhite, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Search listings by product name or category...',
                        hintStyle:
                            GoogleFonts.inter(color: MsmeTheme.textDisabled),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: MsmeTheme.textMuted, size: 20),
                        filled: true,
                        fillColor: MsmeTheme.surfaceDark,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: MsmeTheme.cardBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: MsmeTheme.cardBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: MsmeTheme.primaryOrange)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: MsmeTheme.surfaceDark,
                    underline: const SizedBox.shrink(),
                    items: [
                      'All',
                      'Handicrafts',
                      'Food & Dining',
                      'Tour Services',
                      'Agriculture',
                      'Accommodation'
                    ]
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c,
                                style: GoogleFonts.inter(
                                    color: MsmeTheme.textWhite))))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val ?? 'All'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: listingsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: MsmeTheme.primaryOrange)),
                error: (err, _) => Center(
                    child: Text('Error: $err',
                        style: const TextStyle(color: MsmeTheme.red))),
                data: (listings) {
                  final filtered = listings.where((item) {
                    final name = (item['name'] ?? '').toString().toLowerCase();
                    final category = (item['category'] ?? '').toString();
                    final matchesSearch =
                        name.contains(_searchQuery.toLowerCase());
                    final matchesCategory = _selectedCategory == 'All' ||
                        category == _selectedCategory;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                        child: Text('No listings found.',
                            style: MsmeTheme.body(color: MsmeTheme.textMuted)));
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final listing = filtered[index];
                      final id = listing['id'].toString();
                      final name = (listing['name'] ?? '').toString();
                      final category = (listing['category'] ?? '').toString();
                      final status = (listing['status'] ?? 'Active').toString();

                      return Container(
                        decoration: MsmeTheme.cardDecoration(),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                  color: MsmeTheme.surfaceDark,
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.store_rounded,
                                  color: MsmeTheme.primaryOrange),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: GoogleFonts.plusJakartaSans(
                                          color: MsmeTheme.textWhite,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(category,
                                      style: GoogleFonts.inter(
                                          color: MsmeTheme.textMuted,
                                          fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text(status,
                                      style: GoogleFonts.inter(
                                          color: MsmeTheme.primaryOrange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                TextButton(
                                  onPressed: () => context
                                      .go('/msme-portal/listings/edit/$id'),
                                  child: const Text('Edit'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _confirmDelete(context, id, name),
                                  child: const Text('Delete',
                                      style: TextStyle(color: MsmeTheme.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MsmeTheme.cardDark,
        title: Text('Delete Listing',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$name"?',
            style: GoogleFonts.inter(color: MsmeTheme.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: MsmeTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MsmeTheme.red),
            onPressed: () async {
              final repo = ref.read(msmePortalRepositoryProvider);
              await repo.deleteListing(id);
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(msmePortalListingsProvider);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
