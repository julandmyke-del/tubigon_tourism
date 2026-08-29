import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminReservationManagementPage extends ConsumerStatefulWidget {
  const AdminReservationManagementPage({super.key});

  @override
  ConsumerState<AdminReservationManagementPage> createState() =>
      _AdminReservationManagementPageState();
}

class _AdminReservationManagementPageState
    extends ConsumerState<AdminReservationManagementPage> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(adminReservationsProvider);
    final statusesAsync = ref.watch(adminReservationStatusesProvider);
    final statuses = statusesAsync.value ?? const <Map<String, dynamic>>[];

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
                      style: AppTypography.bodyMedium
                          .copyWith(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AdminColors.cardBg,
                    side: const BorderSide(color: AdminColors.cardBorder),
                  ),
                  onPressed: () => ref.invalidate(adminReservationsProvider),
                  icon: const Icon(Icons.refresh_rounded,
                      color: AdminColors.orange),
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
                      style: const TextStyle(
                          color: AdminColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Search by reservation ID, tourist name, or destination...',
                        hintStyle:
                            const TextStyle(color: AdminColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AdminColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AdminColors.navy900,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AdminColors.cardBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AdminColors.cardBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AdminColors.borderActive)),
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
                        icon: const Icon(Icons.filter_list_rounded,
                            color: AdminColors.textSecondary),
                        style: const TextStyle(
                            color: AdminColors.textPrimary, fontSize: 14),
                        items: [
                          const DropdownMenuItem(
                              value: 'All', child: Text('All Statuses')),
                          ...statuses.map((status) {
                            final name = (status['name'] ?? '').toString();
                            return DropdownMenuItem(
                                value: name, child: Text(_label(name)));
                          }),
                        ],
                        onChanged: (val) =>
                            setState(() => _statusFilter = val!),
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
                      final id = (r['public_reference'] ??
                              r['id'] ??
                              r['reference_no'] ??
                              '')
                          .toString()
                          .toLowerCase();
                      final user = r['user'] is Map
                          ? Map<String, dynamic>.from(r['user'])
                          : const <String, dynamic>{};
                      final statusData = r['status'] is Map
                          ? Map<String, dynamic>.from(r['status'])
                          : const <String, dynamic>{};
                      final tourist =
                          (user['name'] ?? '').toString().toLowerCase();
                      final spot =
                          (r['reservable_name'] ?? r['reservable_type'] ?? '')
                              .toString()
                              .toLowerCase();
                      final status = (statusData['name'] ?? '').toString();

                      final matchesQuery =
                          id.contains(_searchQuery.toLowerCase()) ||
                              tourist.contains(_searchQuery.toLowerCase()) ||
                              spot.contains(_searchQuery.toLowerCase());
                      final matchesStatus = _statusFilter == 'All' ||
                          status.toLowerCase() == _statusFilter.toLowerCase();
                      return matchesQuery && matchesStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                          child: Text(
                              'No reservations match the search criteria.',
                              style:
                                  TextStyle(color: AdminColors.textSecondary)));
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
                          columns: const [
                            DataColumn(
                                label: Text('RESERVATION ID',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('TOURIST',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('DESTINATION',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('DATE',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('PAX',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            DataColumn(
                                label: Text('AMOUNT',
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
                                label: Text('ACTION',
                                    style: TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                          ],
                          rows: filtered.map((r) {
                            final resId = r['id']?.toString() ??
                                r['uuid']?.toString() ??
                                '';
                            final code = (r['public_reference'] ??
                                    r['reference_no'] ??
                                    'RES-${resId.substring(0, resId.length > 4 ? 4 : resId.length)}')
                                .toString();
                            final user = r['user'] is Map
                                ? Map<String, dynamic>.from(r['user'])
                                : const <String, dynamic>{};
                            final statusData = r['status'] is Map
                                ? Map<String, dynamic>.from(r['status'])
                                : const <String, dynamic>{};
                            final tourist =
                                (user['name'] ?? 'Unknown user').toString();
                            final spot = (r['reservable_name'] ??
                                    r['reservable_type'] ??
                                    'Unavailable')
                                .toString();
                            final rawDate = DateTime.tryParse(
                                (r['reservation_date'] ?? '').toString());
                            final date = rawDate == null
                                ? '—'
                                : DateFormat('MMM d, yyyy')
                                    .format(rawDate.toLocal());
                            final pax = (r['guests'] ?? 0).toString();
                            final amountValue =
                                (r['total_amount'] as num?)?.toDouble() ?? 0;
                            final amount =
                                NumberFormat('#,##0.00').format(amountValue);
                            final hasDisplayedFee =
                                r['reservable_type']?.toString() != 'spot' ||
                                    r['fee_configured'] == true;
                            final status =
                                (statusData['name'] ?? 'unknown').toString();
                            final allowedTransitions =
                                (r['allowed_transitions'] as List? ?? const [])
                                    .map((item) => item.toString())
                                    .toSet();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(code,
                                      style: const TextStyle(
                                          color: AdminColors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  onTap: resId.isEmpty
                                      ? null
                                      : () => context
                                          .push('/admin/reservations/$resId'),
                                ),
                                DataCell(Text(tourist,
                                    style: const TextStyle(
                                        color: AdminColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13))),
                                DataCell(Text(spot,
                                    style: const TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontSize: 13))),
                                DataCell(Text(date,
                                    style: const TextStyle(
                                        color: AdminColors.textSecondary,
                                        fontSize: 12))),
                                DataCell(Text('$pax pax',
                                    style: const TextStyle(
                                        color: AdminColors.textPrimary,
                                        fontSize: 13))),
                                DataCell(Text(
                                    hasDisplayedFee ? '₱$amount' : 'Not listed',
                                    style: const TextStyle(
                                        color: AdminColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13))),
                                DataCell(_StatusBadge(status: status)),
                                DataCell(
                                  PopupMenuButton<String>(
                                    enabled: allowedTransitions.isNotEmpty,
                                    icon: const Icon(Icons.more_vert_rounded,
                                        color: AdminColors.textSecondary,
                                        size: 18),
                                    color: AdminColors.navy900,
                                    onSelected: (statusId) async {
                                      try {
                                        await ref
                                            .read(adminRepositoryProvider)
                                            .updateReservationStatus(
                                                resId, statusId);
                                        ref.invalidate(
                                            adminReservationsProvider);
                                        _feedback(
                                            'Reservation status updated.');
                                      } catch (_) {
                                        _feedback(
                                            'Unable to update this reservation.',
                                            error: true);
                                      }
                                    },
                                    itemBuilder: (ctx) => statuses
                                        .where((item) => allowedTransitions
                                            .contains(item['name']?.toString()))
                                        .map((item) {
                                      final id = (item['id'] ?? '').toString();
                                      final name =
                                          (item['name'] ?? '').toString();
                                      return PopupMenuItem(
                                          value: id,
                                          child: Text(_label(name),
                                              style: const TextStyle(
                                                  color: AdminColors
                                                      .textPrimary)));
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AdminColors.orange)),
                  error: (err, _) => const Center(
                      child: Text(
                          'Unable to load reservations. Use Refresh to retry.',
                          style: TextStyle(color: AdminColors.danger))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  void _feedback(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AdminColors.danger : null,
    ));
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
