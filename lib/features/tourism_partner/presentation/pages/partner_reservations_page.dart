import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerReservationsPage extends ConsumerStatefulWidget {
  const PartnerReservationsPage({super.key});

  @override
  ConsumerState<PartnerReservationsPage> createState() => _PartnerReservationsPageState();
}

class _PartnerReservationsPageState extends ConsumerState<PartnerReservationsPage> {
  String _statusFilter = 'all';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _mockFallbackReservations = [
    {
      'id': 'R-0061',
      'listing': 'Island Hopping Adventure',
      'customer': 'Maria Santos',
      'email': 'maria.santos@email.com',
      'date': 'Aug 5, 2026',
      'guests': 4,
      'amount': 7200,
      'status': 'pending',
      'created': '2 hrs ago'
    },
    {
      'id': 'R-0060',
      'listing': 'Scuba Diving Package',
      'customer': 'Juan dela Cruz',
      'email': 'juan.delacruz@email.com',
      'date': 'Aug 6, 2026',
      'guests': 2,
      'amount': 5000,
      'status': 'confirmed',
      'created': '5 hrs ago'
    },
    {
      'id': 'R-0059',
      'listing': 'Dolphin Watching Trip',
      'customer': 'Ana Reyes',
      'email': 'ana.reyes@email.com',
      'date': 'Aug 7, 2026',
      'guests': 6,
      'amount': 9000,
      'status': 'confirmed',
      'created': 'Yesterday'
    },
    {
      'id': 'R-0058',
      'listing': 'Beach BBQ Experience',
      'customer': 'Pedro Lim',
      'email': 'pedro.lim@email.com',
      'date': 'Aug 3, 2026',
      'guests': 3,
      'amount': 3600,
      'status': 'completed',
      'created': '2 days ago'
    },
    {
      'id': 'R-0057',
      'listing': 'Snorkeling at Pandanon',
      'customer': 'Rosa Garcia',
      'email': 'rosa.garcia@email.com',
      'date': 'Aug 2, 2026',
      'guests': 5,
      'amount': 4500,
      'status': 'cancelled',
      'created': '3 days ago'
    },
    {
      'id': 'R-0056',
      'listing': 'Island Hopping Adventure',
      'customer': 'Carlo Mendoza',
      'email': 'carlo.m@email.com',
      'date': 'Aug 8, 2026',
      'guests': 2,
      'amount': 3600,
      'status': 'pending',
      'created': '4 hrs ago'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(partnerReservationsProvider(null));

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: reservationsAsync.when(
        data: (reservations) => _buildBody(reservations.isEmpty ? _mockFallbackReservations : reservations),
        loading: () => const Center(child: CircularProgressIndicator(color: PartnerTheme.primaryOrange)),
        error: (_, __) => _buildBody(_mockFallbackReservations),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> rawReservations) {
    final counts = {
      'all': rawReservations.length,
      'pending': rawReservations.where((r) => r['status'] == 'pending').length,
      'confirmed': rawReservations.where((r) => r['status'] == 'confirmed').length,
      'completed': rawReservations.where((r) => r['status'] == 'completed').length,
      'cancelled': rawReservations.where((r) => r['status'] == 'cancelled').length,
    };

    final filtered = rawReservations.where((r) {
      final id = (r['id'] ?? '').toString().toLowerCase();
      final customer = (r['customer'] ?? '').toString().toLowerCase();
      final listing = (r['listing'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? '').toString().toLowerCase();

      final matchesSearch = id.contains(_searchQuery.toLowerCase()) ||
          customer.contains(_searchQuery.toLowerCase()) ||
          listing.contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5 Summary Filter Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 5 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _summaryCard('Total', counts['all']!, PartnerTheme.textMuted, 'all'),
                  _summaryCard('Pending', counts['pending']!, PartnerTheme.orange, 'pending'),
                  _summaryCard('Confirmed', counts['confirmed']!, PartnerTheme.blue, 'confirmed'),
                  _summaryCard('Completed', counts['completed']!, PartnerTheme.green, 'completed'),
                  _summaryCard('Cancelled', counts['cancelled']!, PartnerTheme.red, 'cancelled'),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: PartnerTheme.cardDecoration(),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: PartnerTheme.textDisabled, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite),
                    decoration: InputDecoration(
                      hintText: 'Search by Booking ID, customer, or listing…',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textDisabled),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Text('${filtered.length} reservations', style: PartnerTheme.label()),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Reservations Table Container
          Container(
            decoration: PartnerTheme.cardDecoration(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.02)),
                dataRowColor: WidgetStateProperty.all(Colors.transparent),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('BOOKING ID')),
                  DataColumn(label: Text('LISTING')),
                  DataColumn(label: Text('CUSTOMER')),
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('GUESTS')),
                  DataColumn(label: Text('AMOUNT')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: filtered.map((r) => _buildDataRow(r)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, int val, Color color, String filterKey) {
    final isSelected = _statusFilter == filterKey;

    return InkWell(
      onTap: () => setState(() => _statusFilter = filterKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : PartnerTheme.cardDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.4) : Color(0x1AFFFFFF),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$val', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: PartnerTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString();
    PartnerBadgeType badgeType = PartnerBadgeType.orange;
    if (status == 'confirmed') badgeType = PartnerBadgeType.blue;
    if (status == 'completed') badgeType = PartnerBadgeType.green;
    if (status == 'cancelled') badgeType = PartnerBadgeType.red;

    final id = r['id'].toString();

    return DataRow(
      onSelectChanged: (_) => _showDetailModal(r),
      cells: [
        DataCell(
          Text(id, style: GoogleFonts.robotoMono(fontSize: 12, color: PartnerTheme.primaryOrange, fontWeight: FontWeight.bold)),
        ),
        DataCell(Text(r['listing'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite, fontWeight: FontWeight.w600))),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r['customer'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite)),
              Text(r['email'] ?? '', style: GoogleFonts.inter(fontSize: 10, color: PartnerTheme.textDisabled)),
            ],
          ),
        ),
        DataCell(Text(r['date'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted))),
        DataCell(Text('${r['guests']} guests', style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted))),
        DataCell(Text('₱${r['amount']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: PartnerTheme.textWhite))),
        DataCell(PartnerBadge(label: status, type: badgeType)),
        DataCell(
          Row(
            children: [
              if (status == 'pending') ...[
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: PartnerTheme.green, size: 18),
                  onPressed: () => _updateStatus(id, 'confirmed'),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: PartnerTheme.red, size: 18),
                  onPressed: () => _updateStatus(id, 'cancelled'),
                ),
              ] else if (status == 'confirmed') ...[
                IconButton(
                  icon: const Icon(Icons.task_alt_rounded, color: PartnerTheme.purple, size: 18),
                  onPressed: () => _updateStatus(id, 'completed'),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: PartnerTheme.textMuted, size: 18),
                onPressed: () => _showDetailModal(r),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateStatus(String id, String status) async {
    try {
      final repo = ref.read(tourismPartnerRepositoryProvider);
      await repo.updateReservationStatus(id, status);
    } catch (_) {}
    ref.invalidate(partnerReservationsProvider);
  }

  void _showDetailModal(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PartnerTheme.cardDark,
        title: Text('Reservation Details (${r['id']})', style: PartnerTheme.headingSmall()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Listing', r['listing']),
            _detailRow('Customer', r['customer']),
            _detailRow('Email', r['email']),
            _detailRow('Date', r['date']),
            _detailRow('Guests', '${r['guests']}'),
            _detailRow('Amount', '₱${r['amount']}'),
            _detailRow('Status', r['status']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(color: PartnerTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String k, dynamic v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted)),
          Text('$v', style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
