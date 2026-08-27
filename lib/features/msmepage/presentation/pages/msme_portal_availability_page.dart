import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../msme_theme.dart';

class MsmePortalAvailabilityPage extends ConsumerStatefulWidget {
  const MsmePortalAvailabilityPage({super.key});

  @override
  ConsumerState<MsmePortalAvailabilityPage> createState() =>
      _MsmePortalAvailabilityPageState();
}

class _MsmePortalAvailabilityPageState
    extends ConsumerState<MsmePortalAvailabilityPage> {
  final Set<int> _blockedDates = {5, 12, 18, 25};
  final Set<int> _fullyBookedDates = {8, 10, 14, 22};

  @override
  Widget build(BuildContext context) {
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
                    Text('Availability Calendar',
                        style: MsmeTheme.headingLarge()),
                    Text(
                      'Block dates, manage holiday schedules, and mark full bookings.',
                      style: MsmeTheme.body(color: MsmeTheme.textMuted),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    MsmeBadge(label: 'Available', type: MsmeBadgeType.green),
                    SizedBox(width: 8),
                    MsmeBadge(label: 'Fully Booked', type: MsmeBadgeType.blue),
                    SizedBox(width: 8),
                    MsmeBadge(
                        label: 'Blocked / Closed', type: MsmeBadgeType.red),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              decoration: MsmeTheme.cardDecoration(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('August 2026', style: MsmeTheme.headingMedium()),
                  Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.chevron_left_rounded,
                              color: MsmeTheme.textWhite),
                          onPressed: () {}),
                      IconButton(
                          icon: const Icon(Icons.chevron_right_rounded,
                              color: MsmeTheme.textWhite),
                          onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Container(
                decoration: MsmeTheme.cardDecoration(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children:
                          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                              .map(
                                (day) => Expanded(
                                  child: Text(
                                    day,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: MsmeTheme.primaryOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const Divider(color: MsmeTheme.cardBorder),
                    Expanded(child: _buildCalendarGrid()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final days = List<int>.generate(31, (index) => index + 1);

    return GridView.count(
      crossAxisCount: 7,
      childAspectRatio: 1,
      children: days.map((day) {
        Color background = MsmeTheme.surfaceDark;
        Color foreground = MsmeTheme.textWhite;
        String label = 'Available';

        if (_blockedDates.contains(day)) {
          background = MsmeTheme.red.withValues(alpha: 0.18);
          foreground = MsmeTheme.red;
          label = 'Blocked';
        } else if (_fullyBookedDates.contains(day)) {
          background = MsmeTheme.blue.withValues(alpha: 0.18);
          foreground = MsmeTheme.blue;
          label = 'Booked';
        }

        return Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MsmeTheme.cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day',
                    style: GoogleFonts.inter(
                        color: foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(label,
                    style: GoogleFonts.inter(
                        color: MsmeTheme.textMuted, fontSize: 10)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
