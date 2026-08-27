import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminReservationManagementPage extends ConsumerStatefulWidget {
  const AdminReservationManagementPage({super.key});

  @override
  ConsumerState<AdminReservationManagementPage> createState() => _AdminReservationManagementPageState();
}

class _AdminReservationManagementPageState extends ConsumerState<AdminReservationManagementPage> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(adminReservationsProvider);

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
                      'Reservation Management',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Oversee tour bookings, resort stays, and municipal spot reservations.',
                      style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: const BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () => ref.invalidate(adminReservationsProvider),
                  icon: const Icon(Icons.refresh_rounded, color: AdminColors.orange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Search & Filters Bar
            Container(
              decoration: AdminColors.glassDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by reservation ID, tourist name, or destination...',
                        hintStyle: const TextStyle(color: AdminColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AdminColors.navy900,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.borderActive)),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AdminColors.navy900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: AdminColors.navy900,
                        value: _statusFilter,
                        icon: const Icon(Icons.filter_list_rounded, color: AdminColors.textSecondary),
                        style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                        items: ['All', 'Confirmed', 'Pending', 'Cancelled']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Statuses' : s)))
                            .toList(),
                        onChanged: (val) => setState(() => _statusFilter = val!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Reservations Table
            Expanded(
              child: Container(
                decoration: AdminColors.glassDecoration(),
                clipBehavior: Clip.antiAlias,
                child: reservationsAsync.when(
                  data: (reservations) {
                    final filtered = reservations.where((r) {
                      final id = (r['id'] ?? r['reference_no'] ?? '').toString().toLowerCase();
                      final tourist = (r['user_name'] ?? r['tourist_name'] ?? r['tourist'] ?? '').toString().toLowerCase();
                      final spot = (r['spot_name'] ?? r['destination'] ?? '').toString().toLowerCase();
                      final status = (r['status'] ?? 'Pending').toString();

                      final matchesQuery = id.contains(_searchQuery.toLowerCase()) ||
                          tourist.contains(_searchQuery.toLowerCase()) ||
                          spot.contains(_searchQuery.toLowerCase());
                      final matchesStatus = _statusFilter == 'All' || status.toLowerCase() == _statusFilter.toLowerCase();
                      return matchesQuery && matchesStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No reservations match the search criteria.', style: TextStyle(color: AdminColors.textSecondary)));
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
                            DataColumn(label: Text('RESERVATION ID', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('TOURIST', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('DESTINATION', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('DATE', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('PAX', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('AMOUNT', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('STATUS', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('ACTION', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: filtered.map((r) {
                            final resId = r['id']?.toString() ?? r['uuid']?.toString() ?? '';
                            final code = (r['reference_no'] ?? 'RES-${resId.substring(0, resId.length > 4 ? 4 : resId.length)}').toString();
                            final tourist = (r['user_name'] ?? r['tourist_name'] ?? r['tourist'] ?? 'Tourist').toString();
                            final spot = (r['spot_name'] ?? r['destination'] ?? 'Spot Booking').toString();
                            final date = (r['reservation_date'] ?? r['date'] ?? '2026-08-05').toString();
                            final pax = (r['number_of_guests'] ?? r['pax'] ?? '1').toString();
                            final amount = (r['total_price'] ?? r['amount'] ?? '2,400').toString();
                            final status = (r['status'] ?? 'Pending').toString();

                            return DataRow(
                              cells: [
                                DataCell(Text(code, style: const TextStyle(color: AdminColors.orange, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataCell(Text(tourist, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                                DataCell(Text(spot, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13))),
                                DataCell(Text(date, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12))),
                                DataCell(Text('$pax pax', style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13))),
                                DataCell(Text('₱$amount', style: const TextStyle(color: AdminColors.success, fontWeight: FontWeight.bold, fontSize: 13))),
                                DataCell(_StatusBadge(status: status)),
                                DataCell(
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: AdminColors.textSecondary, size: 18),
                                    color: AdminColors.navy900,
                                    onSelected: (newStatus) async {
                                      final repo = ref.read(adminRepositoryProvider);
                                      await repo.updateReservationStatus(resId, newStatus);
                                      ref.invalidate(adminReservationsProvider);
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'Confirmed', child: Text('Confirm Booking', style: TextStyle(color: AdminColors.success))),
                                      const PopupMenuItem(value: 'Pending', child: Text('Set Pending', style: TextStyle(color: AdminColors.warning))),
                                      const PopupMenuItem(value: 'Cancelled', child: Text('Cancel Booking', style: TextStyle(color: AdminColors.danger))),
                                    ],
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
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = AdminColors.warningBg;
    Color fg = AdminColors.warning;

    if (s == 'confirmed' || s == 'completed') {
      bg = AdminColors.successBg;
      fg = AdminColors.success;
    } else if (s == 'cancelled' || s == 'rejected') {
      bg = AdminColors.dangerBg;
      fg = AdminColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
