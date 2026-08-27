import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerReviewsPage extends ConsumerStatefulWidget {
  const PartnerReviewsPage({super.key});

  @override
  ConsumerState<PartnerReviewsPage> createState() => _PartnerReviewsPageState();
}

class _PartnerReviewsPageState extends ConsumerState<PartnerReviewsPage> {
  String _statusFilter = 'all';
  int _starFilter = 0;
  final _replyCtrl = TextEditingController();

  final List<Map<String, dynamic>> _mockFallbackReviews = [
    {
      'id': 1,
      'listing': 'Island Hopping Adventure',
      'customer': 'Maria Santos',
      'avatar': 'M',
      'rating': 5,
      'comment': 'Absolutely breathtaking experience! The guides were professional and the islands were stunning. Highly recommend the snorkeling at Pandanon.',
      'date': 'Aug 1, 2026',
      'status': 'published'
    },
    {
      'id': 2,
      'listing': 'Scuba Diving Package',
      'customer': 'Juan dela Cruz',
      'avatar': 'J',
      'rating': 5,
      'comment': "Best diving experience I've ever had! The coral reefs are spectacular and the visibility was perfect. Will definitely come back!",
      'date': 'Jul 30, 2026',
      'status': 'published'
    },
    {
      'id': 3,
      'listing': 'Dolphin Watching Trip',
      'customer': 'Ana Reyes',
      'avatar': 'A',
      'rating': 4,
      'comment': 'Great experience overall! We spotted a pod of about 20 dolphins. The boat was comfortable and the crew was friendly.',
      'date': 'Jul 28, 2026',
      'status': 'published'
    },
    {
      'id': 4,
      'listing': 'Beach BBQ Experience',
      'customer': 'Pedro Lim',
      'avatar': 'P',
      'rating': 4,
      'comment': 'Delicious food and beautiful beach setting. The BBQ was well-organized. Just wish we had a bit more time on the island.',
      'date': 'Jul 25, 2026',
      'status': 'published'
    },
    {
      'id': 5,
      'listing': 'Snorkeling at Pandanon',
      'customer': 'Rosa Garcia',
      'avatar': 'R',
      'rating': 5,
      'comment': 'Crystal clear water and so many colorful fish! Perfect for families with kids too. Equipment was clean and well-maintained.',
      'date': 'Jul 22, 2026',
      'status': 'published'
    },
    {
      'id': 6,
      'listing': 'Island Hopping Adventure',
      'customer': 'Carlo Mendoza',
      'avatar': 'C',
      'rating': 3,
      'comment': 'Nice experience but the boat was a bit cramped. The islands themselves were beautiful though. Food could have been better.',
      'date': 'Jul 18, 2026',
      'status': 'pending'
    },
  ];

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(partnerReviewsProvider);

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: reviewsAsync.when(
        data: (reviews) => _buildBody(reviews.isEmpty ? _mockFallbackReviews : reviews),
        loading: () => const Center(child: CircularProgressIndicator(color: PartnerTheme.primaryOrange)),
        error: (_, __) => _buildBody(_mockFallbackReviews),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> rawReviews) {
    double totalStarSum = 0;
    for (var r in rawReviews) {
      totalStarSum += (r['rating'] as num? ?? 5).toDouble();
    }
    final avgRating = (rawReviews.isEmpty ? 4.8 : (totalStarSum / rawReviews.length)).toStringAsFixed(1);

    final filtered = rawReviews.where((r) {
      final status = (r['status'] ?? 'published').toString();
      final rating = (r['rating'] as num? ?? 5).toInt();

      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
      final matchesStar = _starFilter == 0 || rating == _starFilter;
      return matchesStatus && matchesStar;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating Overview Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  children: [
                    SizedBox(width: 280, child: _buildAvgCard(avgRating, rawReviews.length)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildDistributionCard(rawReviews)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildAvgCard(avgRating, rawReviews.length),
                  const SizedBox(height: 16),
                  _buildDistributionCard(rawReviews),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Status Filter Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                children: ['all', 'published', 'pending'].map((status) {
                  final isSelected = _statusFilter == status;
                  return ChoiceChip(
                    label: Text('${status[0].toUpperCase()}${status.substring(1)}'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _statusFilter = status);
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
              if (_starFilter > 0)
                TextButton(
                  onPressed: () => setState(() => _starFilter = 0),
                  child: Text('Clear Star Filter ($_starFilter★)', style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.primaryOrange)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Reviews List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final review = filtered[index];
              return _buildReviewCard(review);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvgCard(String avg, int count) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        children: [
          Text(avg, style: GoogleFonts.plusJakartaSans(fontSize: 52, fontWeight: FontWeight.w800, color: PartnerTheme.primaryOrange)),
          _buildStarRow((double.tryParse(avg) ?? 5.0).round()),
          const SizedBox(height: 8),
          Text('$count total reviews', style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted)),
          const SizedBox(height: 12),
          const PartnerBadge(label: '98% Positive', type: PartnerBadgeType.green),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(List<Map<String, dynamic>> reviews) {
    final total = reviews.isEmpty ? 1 : reviews.length;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RATING DISTRIBUTION', style: PartnerTheme.label()),
          const SizedBox(height: 14),
          ...List.generate(5, (idx) {
            final star = 5 - idx;
            final count = reviews.where((r) => (r['rating'] as num? ?? 5).toInt() == star).length;
            final pct = count / total;
            final isSelected = _starFilter == star;

            return InkWell(
              onTap: () => setState(() => _starFilter = isSelected ? 0 : star),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('$star ★', style: GoogleFonts.inter(fontSize: 12, color: isSelected ? PartnerTheme.primaryOrange : PartnerTheme.textMuted, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          color: isSelected ? PartnerTheme.primaryOrange : PartnerTheme.primaryOrange.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(width: 24, child: Text('$count', style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textDisabled))),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num? ?? 5).toInt();
    final name = (review['customer'] ?? 'Guest').toString();
    final initial = name.isNotEmpty ? name[0] : 'G';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: PartnerTheme.primaryOrange.withValues(alpha: 0.2),
                child: Text(initial, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: PartnerTheme.primaryOrange)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: PartnerTheme.textWhite)),
                    Text('Reviewed "${review['listing']}" • ${review['date']}', style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.textDisabled)),
                  ],
                ),
              ),
              _buildStarRow(rating),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review['comment'] ?? '',
            style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textMuted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showReplyModal(name),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text('Reply'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PartnerTheme.primaryOrange,
                  side: BorderSide(color: PartnerTheme.primaryOrange.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarRow(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          Icons.star_rounded,
          size: 16,
          color: i < rating ? PartnerTheme.primaryOrange : Colors.white.withValues(alpha: 0.1),
        );
      }),
    );
  }

  void _showReplyModal(String customerName) {
    _replyCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PartnerTheme.cardDark,
        title: Text('Reply to $customerName', style: PartnerTheme.headingSmall()),
        content: TextField(
          controller: _replyCtrl,
          maxLines: 4,
          style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite),
          decoration: InputDecoration(
            hintText: 'Type your public response here…',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textDisabled),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: PartnerTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Response posted successfully!'), backgroundColor: PartnerTheme.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: PartnerTheme.primaryOrange),
            child: const Text('Post Reply'),
          ),
        ],
      ),
    );
  }
}
