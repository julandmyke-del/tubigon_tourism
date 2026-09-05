import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';
import '../widgets/msme_portal_states.dart';

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
    final current = ref.watch(currentMsmeProvider);
    final reservationsAsync =
        ref.watch(msmePortalReservationsProvider(_statusFilter));

    if (current.isLoading) {
      return const Scaffold(
          backgroundColor: MsmeTheme.bgDark,
          body: Center(child: CircularProgressIndicator()));
    }
    if (current.hasError) {
      return Scaffold(
        backgroundColor: MsmeTheme.bgDark,
        body: MsmePortalErrorState(
          message: friendlyMsmeError(
              current.error!, 'We could not load your business account.'),
          onRetry: () => ref.invalidate(currentMsmeProvider),
        ),
      );
    }
    if (current.valueOrNull?.hasBusiness != true) {
      return const Scaffold(
        backgroundColor: MsmeTheme.bgDark,
        body: MsmeSetupRequired(
          title: 'Reservations aren’t available yet',
          message:
              'Complete your business setup before managing customer reservations.',
        ),
      );
    }

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
                hintText: 'Search by guest, business, or booking reference...',
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
                  'Cancelled',
                  'Rejected'
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
                  error: (err, _) => MsmePortalErrorState(
                    message: friendlyMsmeError(
                        err, 'We couldn’t load your reservations.'),
                    onRetry: () => ref.invalidate(
                        msmePortalReservationsProvider(_statusFilter)),
                  ),
                  data: (reservations) {
                    final filtered = reservations.where((r) {
                      final guest =
                          (r['guest_name'] ?? '').toString().toLowerCase();
                      final listing =
                          (r['listing_name'] ?? '').toString().toLowerCase();
                      final reference = (r['public_reference'] ?? r['id'] ?? '')
                          .toString()
                          .toLowerCase();
                      final search = _searchQuery.toLowerCase();
                      return guest.contains(search) ||
                          listing.contains(search) ||
                          reference.contains(search);
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(guestName,
                                      style: GoogleFonts.plusJakartaSans(
                                          color: MsmeTheme.textWhite,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                                MsmeBadge(
                                    label: status.replaceAll('_', ' '),
                                    type: status == 'completed'
                                        ? MsmeBadgeType.green
                                        : status == 'cancelled' ||
                                                status == 'rejected'
                                            ? MsmeBadgeType.red
                                            : MsmeBadgeType.orange),
                                if (allowed.isNotEmpty)
                                  PopupMenuButton<String>(
                                    tooltip: 'Update reservation status',
                                    onSelected: (value) =>
                                        _changeStatus(id, value),
                                    itemBuilder: (_) => allowed
                                        .map((value) => PopupMenuItem(
                                              value: value,
                                              child: Text(value.replaceFirst(
                                                  value[0],
                                                  value[0].toUpperCase())),
                                            ))
                                        .toList(),
                                  ),
                              ]),
                              Text(listingName,
                                  style: GoogleFonts.inter(
                                      color: MsmeTheme.textMuted)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 18, runSpacing: 6, children: [
                                _detail(Icons.confirmation_number_outlined,
                                    reservation['public_reference'] ?? id),
                                _detail(Icons.event_rounded,
                                    reservation['reservation_date'] ?? '—'),
                                _detail(
                                    Icons.schedule_rounded,
                                    reservation['start_time'] ??
                                        'Time not set'),
                                _detail(Icons.groups_rounded,
                                    '${reservation['guests'] ?? 1} guest(s)'),
                              ]),
                              if ((reservation['notes']?.toString() ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Note: ${reservation['notes']}',
                                    style: GoogleFonts.inter(
                                        color: MsmeTheme.textMuted,
                                        fontStyle: FontStyle.italic)),
                              ],
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

  Widget _detail(IconData icon, Object value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: MsmeTheme.textDisabled),
          const SizedBox(width: 5),
          Text('$value',
              style:
                  GoogleFonts.inter(color: MsmeTheme.textMuted, fontSize: 12)),
        ],
      );

  Future<void> _changeStatus(String id, String status) async {
    String? reason;
    if (status == 'rejected' || status == 'cancelled') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
              '${status == 'rejected' ? 'Reject' : 'Cancel'} reservation?'),
          content: TextField(
            controller: controller,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Reason *',
                helperText: 'The tourist will receive this reason.'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Keep Reservation')),
            FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) Navigator.pop(dialogContext, value);
                },
                child: Text(status == 'rejected' ? 'Reject' : 'Cancel')),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
    }

    try {
      await ref
          .read(msmePortalRepositoryProvider)
          .updateReservationStatus(id, status, reason: reason);
      if (!mounted) return;
      ref.invalidate(msmePortalReservationsProvider(_statusFilter));
      ref.invalidate(msmePortalDashboardStatsProvider);
      ref.invalidate(msmePortalAnalyticsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: MsmeTheme.green,
          content: Text('Reservation $status.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: MsmeTheme.red,
            content: Text(friendlyMsmeError(
                error, 'We couldn’t update this reservation.'))));
      }
    }
  }
}
