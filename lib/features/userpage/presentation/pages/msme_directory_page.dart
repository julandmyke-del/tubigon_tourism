import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../msmepage/models/msme.dart';
import '../../../msmepage/repositories/msme_repository.dart';

const _categories = [
  'All',
  'Food & Dining',
  'Tour Services',
  'Handicrafts',
  'Agriculture',
  'Accommodation',
];

class MsmeDirectoryPage extends ConsumerStatefulWidget {
  const MsmeDirectoryPage({super.key});

  @override
  ConsumerState<MsmeDirectoryPage> createState() => _MsmeDirectoryPageState();
}

class _MsmeDirectoryPageState extends ConsumerState<MsmeDirectoryPage> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _verifiedOnly = true;
  double _minimumRating = 0;
  Timer? _searchDebounce;
  final _searchCtrl = TextEditingController();

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msmesAsync = ref.watch(msmeListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'MSME Directory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search local businesses, crafts, food…',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 12),

          // Categories
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  backgroundColor: const Color(0xFF0F172A),
                  selectedColor: const Color(0xFFF59E0B),
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : const Color(0xFFCBD5E1),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Verified only'),
                  avatar: const Icon(Icons.verified_rounded, size: 16),
                  selected: _verifiedOnly,
                  onSelected: (value) => setState(() => _verifiedOnly = value),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<double>(
                  initialValue: _minimumRating,
                  tooltip: 'Minimum rating',
                  onSelected: (value) => setState(() => _minimumRating = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0, child: Text('Any rating')),
                    PopupMenuItem(value: 3, child: Text('3+ stars')),
                    PopupMenuItem(value: 4, child: Text('4+ stars')),
                  ],
                  child: Chip(
                      label: Text(_minimumRating == 0
                          ? 'Any rating'
                          : '${_minimumRating.toInt()}+ stars')),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // MSME list
          Expanded(
            child: msmesAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, __) => Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                ),
              ),
              error: (err, _) => Center(
                child: Text('Error loading MSMEs: $err',
                    style: const TextStyle(color: Colors.white70)),
              ),
              data: (allMsmes) {
                final filtered = allMsmes.where((m) {
                  final matchCat = _selectedCategory == 'All' ||
                      m.category == _selectedCategory;
                  final searchable =
                      '${m.name} ${m.category} ${m.description} ${m.address ?? ''} ${m.tagline} ${m.products.map((p) => p.name).join(' ')}'
                          .toLowerCase();
                  final matchSearch =
                      searchable.contains(_searchQuery.toLowerCase());
                  final matchVerified = !_verifiedOnly || m.isVerified;
                  final matchRating = (m.rating ?? 0) >= _minimumRating;
                  return matchCat &&
                      matchSearch &&
                      matchVerified &&
                      matchRating;
                }).toList()
                  ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 64, color: Color(0xFF475569)),
                        SizedBox(height: 16),
                        Text('No MSMEs found',
                            style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFFF59E0B),
                  backgroundColor: const Color(0xFF0F172A),
                  onRefresh: () => ref.refresh(msmeListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      return _MsmeCard(msme: filtered[i], index: i);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MsmeCard extends StatelessWidget {
  const _MsmeCard({required this.msme, required this.index});

  final Msme msme;
  final int index;

  @override
  Widget build(BuildContext context) {
    Color catColor = const Color(0xFFF59E0B);
    IconData catIcon = Icons.store_rounded;

    if (msme.category == 'Food & Dining') {
      catColor = const Color(0xFFF87171);
      catIcon = Icons.restaurant_rounded;
    } else if (msme.category == 'Tour Services') {
      catColor = const Color(0xFF38BDF8);
      catIcon = Icons.sailing_rounded;
    } else if (msme.category == 'Handicrafts') {
      catColor = const Color(0xFFC084FC);
      catIcon = Icons.local_offer_rounded;
    } else if (msme.category == 'Agriculture') {
      catColor = const Color(0xFF34D399);
      catIcon = Icons.agriculture_rounded;
    } else if (msme.category == 'Accommodation') {
      catColor = const Color(0xFFF59E0B);
      catIcon = Icons.home_rounded;
    }

    return GestureDetector(
      onTap: () => context.goNamed(
        RouteNames.msmeDetail,
        pathParameters: {'id': msme.id.toString()},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 90,
              height: 110,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Icon(catIcon, color: catColor, size: 40),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            msme.category,
                            style: TextStyle(
                                color: catColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (msme.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF38BDF8), size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      msme.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msme.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child:
                  Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ).animate(delay: (60 * index).ms).fadeIn(duration: 350.ms),
    );
  }
}
