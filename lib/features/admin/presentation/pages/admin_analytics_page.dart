import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminAnalyticsPage extends ConsumerWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: statsAsync.when(
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tourism Metrics',
                          style: AppTypography.headlineMedium.copyWith(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current totals and recent activity from the operational database.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh metrics',
                    onPressed: () =>
                        ref.invalidate(adminDashboardStatsProvider),
                    icon: const Icon(Icons.refresh_rounded,
                        color: AdminColors.orange),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 4
                      : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                  final cards = [
                    (
                      'Registered Users',
                      stats['totalUsers'],
                      Icons.people_rounded,
                      AdminColors.orange
                    ),
                    (
                      'Tourists',
                      stats['totalTourists'],
                      Icons.hiking_rounded,
                      AdminColors.info
                    ),
                    (
                      'MSMEs',
                      stats['totalMsmes'],
                      Icons.store_rounded,
                      AdminColors.purple
                    ),
                    (
                      'Tourist Spots',
                      stats['totalSpots'],
                      Icons.landscape_rounded,
                      AdminColors.success
                    ),
                    (
                      'Reservations',
                      stats['totalReservations'],
                      Icons.calendar_month_rounded,
                      AdminColors.warning
                    ),
                    (
                      'Reviews',
                      stats['totalReviews'],
                      Icons.rate_review_rounded,
                      AdminColors.info
                    ),
                    (
                      'Waste Reports',
                      stats['totalWasteReports'],
                      Icons.delete_outline_rounded,
                      AdminColors.danger
                    ),
                    (
                      'Reservations (30 days)',
                      stats['reservationsLast30Days'],
                      Icons.trending_up_rounded,
                      AdminColors.success
                    ),
                    (
                      'Waste Reports (30 days)',
                      stats['wasteReportsLast30Days'],
                      Icons.eco_rounded,
                      AdminColors.warning
                    ),
                    (
                      'Tourism Partners',
                      stats['totalPartners'],
                      Icons.handshake_rounded,
                      AdminColors.info
                    ),
                    (
                      'Verified MSMEs',
                      stats['verifiedMsmes'],
                      Icons.verified_rounded,
                      AdminColors.success
                    ),
                    (
                      'Published Spots',
                      stats['publishedSpots'],
                      Icons.public_rounded,
                      AdminColors.purple
                    ),
                    (
                      'Active Ferry Services',
                      stats['activeFerrySchedules'],
                      Icons.directions_boat_rounded,
                      AdminColors.info
                    ),
                  ];
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: columns == 1 ? 3.2 : 1.8,
                    children: cards
                        .map((card) => _MetricCard(
                              title: card.$1,
                              value: (card.$2 as num?)?.toInt() ?? 0,
                              icon: card.$3,
                              color: card.$4,
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final panels = <Widget>[
                    _BreakdownPanel(
                      title: 'Reservation status',
                      emptyMessage: 'No reservations recorded.',
                      rows: _rows(stats['reservationStatuses']),
                    ),
                    _BreakdownPanel(
                      title: 'Waste report status',
                      emptyMessage: 'No waste reports recorded.',
                      rows: _rows(stats['wasteStatuses']),
                    ),
                    _BreakdownPanel(
                      title: 'Access applications',
                      emptyMessage: 'No access applications recorded.',
                      rows: _rows(stats['roleApplicationStatuses']),
                    ),
                    _DestinationPanel(
                      rows: _rows(stats['mostReservedDestinations']),
                    ),
                  ];
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: panels
                          .map((panel) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md),
                                child: panel,
                              ))
                          .toList(),
                    );
                  }
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 2.1,
                    children: panels,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _ThirtyDayActivityPanel(
                reservations: _rows(stats['reservationsOverTime']),
                wasteReports: _rows(stats['wasteReportsOverTime']),
                reservationValue:
                    (stats['reservationValueLast30Days'] as num?)?.toDouble() ??
                        0,
              ),
            ],
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdminColors.orange),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load metrics.',
                  style: TextStyle(color: AdminColors.danger)),
              TextButton(
                onPressed: () => ref.invalidate(adminDashboardStatsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AdminColors.glassDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                Text(title,
                    style: TextStyle(
                        color: AdminColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownPanel extends StatelessWidget {
  const _BreakdownPanel({
    required this.title,
    required this.emptyMessage,
    required this.rows,
  });

  final String title;
  final String emptyMessage;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsPanel(
      title: title,
      child: rows.isEmpty
          ? Text(emptyMessage,
              style: TextStyle(color: AdminColors.textSecondary))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rows
                  .map((row) => Chip(
                        backgroundColor: AdminColors.navy800,
                        side: BorderSide(color: AdminColors.border),
                        label: Text(
                          '${_label(row['label'])}: ${(row['total'] as num?)?.toInt() ?? 0}',
                          style:
                              TextStyle(color: AdminColors.textPrimary),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

class _DestinationPanel extends StatelessWidget {
  const _DestinationPanel({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsPanel(
      title: 'Most reserved destinations',
      child: rows.isEmpty
          ? Text('No reservation destinations recorded.',
              style: TextStyle(color: AdminColors.textSecondary))
          : Column(
              children: rows
                  .map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 16, color: AdminColors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${row['name'] ?? 'Unavailable'}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AdminColors.textPrimary)),
                            ),
                            Text('${(row['total'] as num?)?.toInt() ?? 0}',
                                style: TextStyle(
                                    color: AdminColors.textSecondary,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

class _ThirtyDayActivityPanel extends StatelessWidget {
  const _ThirtyDayActivityPanel({
    required this.reservations,
    required this.wasteReports,
    required this.reservationValue,
  });

  final List<Map<String, dynamic>> reservations;
  final List<Map<String, dynamic>> wasteReports;
  final double reservationValue;

  @override
  Widget build(BuildContext context) {
    Widget series(String label, List<Map<String, dynamic>> rows, Color color) {
      final recent = rows.reversed.take(7).toList().reversed;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              Text('No activity in this period.',
                  style: TextStyle(color: AdminColors.textSecondary))
            else
              ...recent.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${row['date'] ?? ''}',
                              style: TextStyle(
                                  color: AdminColors.textSecondary,
                                  fontSize: 12)),
                        ),
                        Text('${(row['total'] as num?)?.toInt() ?? 0}',
                            style: TextStyle(
                                color: AdminColors.textPrimary,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
          ],
        ),
      );
    }

    return _AnalyticsPanel(
      title: 'Last 30 days · recorded activity',
      subtitle:
          'Reservation value recorded: ₱${reservationValue.toStringAsFixed(2)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          series('Reservations', reservations, AdminColors.success),
          const SizedBox(width: AppSpacing.lg),
          series('Waste reports', wasteReports, AdminColors.warning),
        ],
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AdminColors.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: TextStyle(
                    color: AdminColors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

String _label(dynamic value) {
  final raw = '${value ?? 'unknown'}'.replaceAll('_', ' ');
  if (raw.isEmpty) return 'Unknown';
  return '${raw[0].toUpperCase()}${raw.substring(1)}';
}
