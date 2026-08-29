import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalReservationsPage extends ConsumerStatefulWidget {
  const MsmePortalReservationsPage({super.key});

  @override
  ConsumerState<MsmePortalReservationsPage> createState() =>
      _MsmePortalReservationsPageState();
}

class _MsmePortalReservationsPageState
    extends ConsumerState<MsmePortalReservationsPage> {
  String _statusFilter = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final reservationsAsync =
        ref.watch(msmePortalReservationsProvider(_statusFilter));

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
                    Text('Reservation Management',
                        style: MsmeTheme.headingLarge()),
                    Text(
                        'Review, accept, reject, and complete customer bookings.',
                        style: MsmeTheme.body(color: MsmeTheme.textMuted)),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                      backgroundColor: MsmeTheme.surfaceDark),
                  onPressed: () => ref.invalidate(
                      msmePortalReservationsProvider(_statusFilter)),
                  icon: const Icon(Icons.refresh_rounded,
                      color: MsmeTheme.primaryOrange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.inter(color: MsmeTheme.textWhite),
              decoration: InputDecoration(
                hintText: 'Search by guest or listing name...',
                hintStyle: GoogleFonts.inter(color: MsmeTheme.textDisabled),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: MsmeTheme.textMuted),
                filled: true,
                fillColor: MsmeTheme.surfaceDark,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: MsmeTheme.cardBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: MsmeTheme.cardBorder)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Pending',
                  'Confirmed',
                  'Completed',
                  'Cancelled'
                ].map((status) {
                  final selected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status),
                      selected: selected,
                      onSelected: (_) => setState(() => _statusFilter = status),
                      backgroundColor: MsmeTheme.surfaceDark,
                      selectedColor: MsmeTheme.primaryOrange,
                      labelStyle: GoogleFonts.inter(
                          color: selected ? Colors.white : MsmeTheme.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Container(
                decoration: MsmeTheme.cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: reservationsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: MsmeTheme.primaryOrange)),
                  error: (err, _) => Center(
                      child: OutlinedButton(
                          onPressed: () => ref.invalidate(
                              msmePortalReservationsProvider(_statusFilter)),
                          child: Text('Retry: $err'))),
                  data: (reservations) {
                    final filtered = reservations.where((r) {
                      final guest =
                          (r['guest_name'] ?? '').toString().toLowerCase();
                      final listing =
                          (r['listing_name'] ?? '').toString().toLowerCase();
                      final search = _searchQuery.toLowerCase();
                      return guest.contains(search) || listing.contains(search);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                          child: Text('No reservations found.',
                              style:
                                  MsmeTheme.body(color: MsmeTheme.textMuted)));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final reservation = filtered[index];
                        final id = reservation['id'].toString();
                        final guestName =
                            (reservation['guest_name'] ?? 'Guest').toString();
                        final listingName =
                            (reservation['listing_name'] ?? 'Listing')
                                .toString();
                        final status =
                            (reservation['status'] ?? 'pending').toString();
                        final allowed = switch (status) {
                          'pending' => const [
                              'confirmed',
                              'rejected',
                              'cancelled'
                            ],
                          'approved' => const [
                              'confirmed',
                              'completed',
                              'cancelled'
                            ],
                          'confirmed' => const ['completed', 'cancelled'],
                          _ => const <String>[],
                        };

                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: MsmeTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: MsmeTheme.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(guestName,
                                        style: GoogleFonts.plusJakartaSans(
                                            color: MsmeTheme.textWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(listingName,
                                        style: GoogleFonts.inter(
                                            color: MsmeTheme.textMuted)),
                                    const SizedBox(height: 4),
                                    Text(status,
                                        style: GoogleFonts.inter(
                                            color: MsmeTheme.primaryOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (allowed.isNotEmpty)
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    try {
                                      final repo = ref
                                          .read(msmePortalRepositoryProvider);
                                      await repo.updateReservationStatus(
                                          id, value);
                                      ref.invalidate(
                                          msmePortalReservationsProvider(
                                              _statusFilter));
                                      ref.invalidate(
                                          msmePortalDashboardStatsProvider);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              backgroundColor: MsmeTheme.green,
                                              content:
                                                  Text('Reservation $value.')),
                                        );
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              backgroundColor: MsmeTheme.red,
                                              content: Text(error.toString())),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => allowed
                                      .map((value) => PopupMenuItem(
                                            value: value,
                                            child: Text(value.replaceFirst(
                                                value[0],
                                                value[0].toUpperCase())),
                                          ))
                                      .toList(),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
