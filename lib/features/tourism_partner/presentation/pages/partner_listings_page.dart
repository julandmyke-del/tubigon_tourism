import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerListingsPage extends ConsumerStatefulWidget {
  const PartnerListingsPage({super.key});

  @override
  ConsumerState<PartnerListingsPage> createState() => _PartnerListingsPageState();
}

class _PartnerListingsPageState extends ConsumerState<PartnerListingsPage> {
  String _statusFilter = 'all';
  String _searchQuery = '';
  String _sortBy = 'reservations';
  int _currentPage = 1;
  static const int _perPage = 6;

  final List<Map<String, dynamic>> _mockFallbackListings = [
    {
      'id': '1',
      'name': 'Island Hopping Adventure',
      'category': 'Island Tour',
      'location': 'Tubigon Pier',
      'price': 1800,
      'status': 'active',
      'rating': 4.9,
      'reviews': 87,
      'reservations': 48,
      'icon': '🏝️',
      'created': 'Jan 15, 2026'
    },
    {
      'id': '2',
      'name': 'Scuba Diving Package',
      'category': 'Diving',
      'location': 'Pandanon Island',
      'price': 2500,
      'status': 'active',
      'rating': 4.8,
      'reviews': 63,
      'reservations': 36,
      'icon': '🤿',
      'created': 'Feb 3, 2026'
    },
    {
      'id': '3',
      'name': 'Dolphin Watching Trip',
      'category': 'Wildlife',
      'location': 'Cebu Strait',
      'price': 1500,
      'status': 'active',
      'rating': 4.7,
      'reviews': 52,
      'reservations': 29,
      'icon': '🐬',
      'created': 'Feb 18, 2026'
    },
    {
      'id': '4',
      'name': 'Beach BBQ Experience',
      'category': 'Dining',
      'location': 'Virgin Island',
      'price': 1200,
      'status': 'active',
      'rating': 4.6,
      'reviews': 41,
      'reservations': 22,
      'icon': '🍖',
      'created': 'Mar 5, 2026'
    },
    {
      'id': '5',
      'name': 'Snorkeling at Pandanon',
      'category': 'Snorkeling',
      'location': 'Pandanon Island',
      'price': 900,
      'status': 'active',
      'rating': 4.8,
      'reviews': 38,
      'reservations': 18,
      'icon': '🐠',
      'created': 'Mar 22, 2026'
    },
    {
      'id': '6',
      'name': 'Bohol Day Tour Package',
      'category': 'Land Tour',
      'location': 'Bohol Province',
      'price': 2200,
      'status': 'pending',
      'rating': 0.0,
      'reviews': 0,
      'reservations': 0,
      'icon': '🚐',
      'created': 'Jul 28, 2026'
    },
    {
      'id': '7',
      'name': 'Mangrove Kayaking Tour',
      'category': 'Adventure',
      'location': 'Tubigon Mangrove',
      'price': 650,
      'status': 'inactive',
      'rating': 4.5,
      'reviews': 14,
      'reservations': 8,
      'icon': '🚣',
      'created': 'Apr 10, 2026'
    },
    {
      'id': '8',
      'name': 'Sunset Cruising Trip',
      'category': 'Cruising',
      'location': 'Tubigon Waters',
      'price': 1400,
      'status': 'active',
      'rating': 4.9,
      'reviews': 29,
      'reservations': 15,
      'icon': '🌅',
      'created': 'May 1, 2026'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(partnerListingsProvider);

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/tourism-partner/listings/create'),
        backgroundColor: PartnerTheme.primaryOrange,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Create Listing', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: listingsAsync.when(
        data: (listings) => _buildBody(listings.isEmpty ? _mockFallbackListings : listings),
        loading: () => const Center(child: CircularProgressIndicator(color: PartnerTheme.primaryOrange)),
        error: (_, __) => _buildBody(_mockFallbackListings),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> rawListings) {
    // Counts
    final counts = {
      'all': rawListings.length,
      'active': rawListings.where((l) => l['status'] == 'active').length,
      'inactive': rawListings.where((l) => l['status'] == 'inactive').length,
      'pending': rawListings.where((l) => l['status'] == 'pending').length,
    };

    // Filter & Sort
    final filtered = rawListings.where((l) {
      final name = (l['name'] ?? '').toString().toLowerCase();
      final cat = (l['category'] ?? '').toString().toLowerCase();
      final status = (l['status'] ?? 'active').toString().toLowerCase();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || cat.contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'name') {
        return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      } else if (_sortBy == 'rating') {
        return ((b['rating'] ?? 0) as num).compareTo((a['rating'] ?? 0) as num);
      } else if (_sortBy == 'price') {
        return ((b['price'] ?? 0) as num).compareTo((a['price'] ?? 0) as num);
      }
      return ((b['reservations'] ?? 0) as num).compareTo((a['reservations'] ?? 0) as num);
    });

    final totalPages = (filtered.length / _perPage).ceil().clamp(1, 999);
    final startIndex = (_currentPage - 1) * _perPage;
    final pagedListings = filtered.skip(startIndex).take(_perPage).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Tabs & Add Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['all', 'active', 'inactive', 'pending'].map((status) {
                  final isSelected = _statusFilter == status;
                  final count = counts[status] ?? 0;
                  return ChoiceChip(
                    label: Text('${status[0].toUpperCase()}${status.substring(1)} ($count)'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _statusFilter = status;
                          _currentPage = 1;
                        });
                      }
                    },
                    selectedColor: PartnerTheme.primaryOrange.withValues(alpha: 0.2),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: isSelected ? PartnerTheme.primaryOrange : Colors.white.withValues(alpha: 0.08),
                    ),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? PartnerTheme.primaryOrange : PartnerTheme.textDisabled,
                    ),
                  );
                }).toList(),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/tourism-partner/listings/create'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Listing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PartnerTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search & Sort Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: PartnerTheme.cardDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    }),
                    style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite),
                    decoration: InputDecoration(
                      hintText: 'Search listing by name or category…',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textDisabled),
                      prefixIcon: const Icon(Icons.search_rounded, color: PartnerTheme.textDisabled, size: 20),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: PartnerTheme.cardDark,
                  underline: const SizedBox(),
                  style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted),
                  icon: const Icon(Icons.sort_rounded, color: PartnerTheme.textMuted, size: 18),
                  items: const [
                    DropdownMenuItem(value: 'reservations', child: Text('Sort by Bookings')),
                    DropdownMenuItem(value: 'rating', child: Text('Sort by Rating')),
                    DropdownMenuItem(value: 'price', child: Text('Sort by Price')),
                    DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _sortBy = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Listings Grid
          if (pagedListings.isEmpty)
            Container(
              padding: const EdgeInsets.all(60),
              width: double.infinity,
              decoration: PartnerTheme.cardDecoration(),
              child: Column(
                children: [
                  const Text('🏖️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('No listings found', style: PartnerTheme.headingSmall()),
                  Text('Try adjusting your search or filters.', style: PartnerTheme.label()),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 3 : (constraints.maxWidth > 600 ? 2 : 1),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: pagedListings.length,
                  itemBuilder: (context, index) {
                    final item = pagedListings[index];
                    return _buildListingCard(item);
                  },
                );
              },
            ),
          const SizedBox(height: 24),

          // Pagination
          if (totalPages > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  icon: const Icon(Icons.chevron_left_rounded, color: PartnerTheme.textMuted),
                ),
                Text(
                  'Page $_currentPage of $totalPages',
                  style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textMuted),
                ),
                IconButton(
                  onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  icon: const Icon(Icons.chevron_right_rounded, color: PartnerTheme.textMuted),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'active').toString();
    PartnerBadgeType badgeType = PartnerBadgeType.green;
    if (status == 'pending') badgeType = PartnerBadgeType.orange;
    if (status == 'inactive') badgeType = PartnerBadgeType.gray;

    final id = item['id'].toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PartnerTheme.primaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(item['icon'] ?? '🏝️', style: const TextStyle(fontSize: 22)),
                ),
              ),
              PartnerBadge(label: status, type: badgeType),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? 'Listing',
                style: PartnerTheme.headingSmall(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: PartnerTheme.textDisabled),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${item['category']} • ${item['location']}',
                      style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textDisabled),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₱${item['price']}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: PartnerTheme.primaryOrange),
                  ),
                  Text(
                    '⭐ ${item['rating']} (${item['reservations']} bookings)',
                    style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0x1AFFFFFF)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => context.go('/tourism-partner/listings/edit/$id'),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: PartnerTheme.textMuted),
              ),
              IconButton(
                onPressed: () => _confirmDelete(id, item['name'] ?? 'Listing'),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: PartnerTheme.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PartnerTheme.cardDark,
        title: Text('Delete Listing', style: PartnerTheme.headingSmall()),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.', style: GoogleFonts.inter(color: PartnerTheme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: PartnerTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(tourismPartnerRepositoryProvider);
                await repo.deleteListing(id);
              } catch (_) {}
              ref.invalidate(partnerListingsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: PartnerTheme.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
