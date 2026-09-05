import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguDashboardPage extends ConsumerWidget {
  const LguDashboardPage({super.key});

  static const _surface = Color(0xFF1C2541);
  static const _border = Color(0xFF334155);
  static const _accent = Color(0xFFF97316);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(lguDashboardStatsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: stats.when(
        loading: () => const _DashboardSkeleton(),
        error: (error, _) => _DashboardState(
          icon: Icons.cloud_off_rounded,
          title: 'Municipal operations could not be loaded.',
          message: error.toString(),
          onRetry: () => ref.invalidate(lguDashboardStatsProvider),
        ),
        data: (data) => _content(context, ref, data),
      ),
    );
  }

  Widget _content(
      BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final action = _map(data['actionCenter']);
    final alerts = _list(data['operationalAlerts']);
    final activity = _list(data['recentActivity']);
    final lastSynced =
        DateTime.tryParse(data['lastSyncedAt']?.toString() ?? '');
    final metrics = <_MetricData>[
      _MetricData('Tourist Spots', _int(data['totalSpots']),
          Icons.place_rounded, '/lgu/tourist-spots'),
      _MetricData('Verified MSMEs', _int(data['verifiedMsmes']),
          Icons.verified_rounded, '/lgu/msme'),
      _MetricData('MSMEs Awaiting Review', _int(action['msmesAwaitingReview']),
          Icons.fact_check_rounded, '/lgu/msme'),
      _MetricData('Active Reservations', _int(data['activeReservations']),
          Icons.event_available_rounded, '/lgu/reservations'),
      _MetricData('Pending Waste Reports', _int(data['pendingWasteReports']),
          Icons.pending_actions_rounded, '/lgu/waste-reports'),
      _MetricData('Resolved Waste Reports', _int(data['resolvedWasteReports']),
          Icons.task_alt_rounded, '/lgu/waste-reports'),
      _MetricData(
          'Emergency Reviews',
          _int(action['emergencyContactsNeedingVerification']),
          Icons.emergency_rounded,
          '/lgu/emergency'),
      _MetricData('Map Reviews', _int(action['mapLocationsNeedingReview']),
          Icons.add_location_alt_rounded, '/lgu/map-locations'),
      _MetricData('Active Announcements', _int(data['activeAnnouncements']),
          Icons.campaign_rounded, '/lgu/announcements'),
    ];

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(lguDashboardStatsProvider.future),
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Municipal Operations Command Center',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(
                      'Tourism supervision, public safety, and field operations',
                      style: TextStyle(color: AppColors.grey400)),
                ],
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sync_rounded,
                    size: 16, color: AppColors.grey400),
                const SizedBox(width: 6),
                Text(
                  lastSynced == null
                      ? 'Live data'
                      : 'Synced ${DateFormat('MMM d, h:mm a').format(lastSynced.toLocal())}',
                  style:
                      const TextStyle(color: AppColors.grey400, fontSize: 12),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1180
                ? 4
                : width >= 720
                    ? 3
                    : width >= 460
                        ? 2
                        : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 126,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, index) =>
                  _MetricCard(data: metrics[index]),
            );
          }),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final alertsPanel = _Panel(
              title: 'Operational Alerts',
              icon: Icons.warning_amber_rounded,
              child: alerts.isEmpty
                  ? const _InlineEmpty(
                      icon: Icons.check_circle_outline_rounded,
                      message: 'No outstanding operational alerts.')
                  : Column(
                      children: alerts
                          .map((item) => _AlertRow(
                                item: item,
                                onTap: () => context
                                    .go(item['route']?.toString() ?? '/lgu'),
                              ))
                          .toList(),
                    ),
            );
            const actionsPanel = _QuickActions();
            if (!wide) {
              return Column(children: [
                alertsPanel,
                const SizedBox(height: 12),
                actionsPanel
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: alertsPanel),
              const SizedBox(width: 12),
              const Expanded(child: actionsPanel),
            ]);
          }),
          const SizedBox(height: 22),
          _Panel(
            title: 'Recent Municipal Activity',
            icon: Icons.history_rounded,
            trailing: TextButton(
              onPressed: () => context.go('/lgu/tourism-monitoring'),
              child: const Text('View activity'),
            ),
            child: activity.isEmpty
                ? const _InlineEmpty(
                    icon: Icons.history_toggle_off_rounded,
                    message: 'No municipal activity has been recorded yet.')
                : Column(
                    children: activity
                        .map((item) => _ActivityRow(item: item))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  static int _int(dynamic value) => int.tryParse('$value') ?? 0;
  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.route);
  final String label;
  final int value;
  final IconData icon;
  final String route;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});
  final _MetricData data;
  @override
  Widget build(BuildContext context) => Material(
        color: LguDashboardPage._surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go(data.route),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LguDashboardPage._border),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: LguDashboardPage._accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(data.icon, color: LguDashboardPage._accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${data.value}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800)),
                    Text(data.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.grey400, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
            ]),
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel(
      {required this.title,
      required this.icon,
      required this.child,
      this.trailing});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: LguDashboardPage._surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LguDashboardPage._border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: LguDashboardPage._accent, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          Material(color: Colors.transparent, child: child),
        ]),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  static const actions = [
    ('Review MSMEs', Icons.fact_check_rounded, '/lgu/msme'),
    ('Monitor Spots', Icons.place_rounded, '/lgu/tourist-spots'),
    ('Open Smart Map', Icons.map_rounded, '/map'),
    ('Waste Reports', Icons.delete_outline_rounded, '/lgu/waste-reports'),
    ('Announcements', Icons.campaign_rounded, '/lgu/announcements'),
    ('View Analytics', Icons.bar_chart_rounded, '/lgu/analytics'),
    ('Generate Report', Icons.assessment_rounded, '/lgu/reports'),
  ];
  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Quick Municipal Actions',
        icon: Icons.bolt_rounded,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions
              .map((item) => ActionChip(
                    avatar: Icon(item.$2, size: 17),
                    label: Text(item.$1),
                    onPressed: () => context.go(item.$3),
                  ))
              .toList(),
        ),
      );
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading:
            const Icon(Icons.error_outline_rounded, color: Color(0xFFF59E0B)),
        title: Text(item['message']?.toString() ?? 'Municipal action required',
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey400),
        onTap: onTap,
      );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0x3322C55E),
        child: Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 18),
      ),
      title: Text(item['action']?.toString() ?? 'Municipal activity',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${item['target'] ?? 'Municipal record'} • ${item['actor'] ?? 'Authorized user'}',
        style: const TextStyle(color: AppColors.grey400),
      ),
      trailing: Text(
          time == null
              ? '—'
              : DateFormat('MMM d, h:mm a').format(time.toLocal()),
          style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          Icon(icon, color: AppColors.grey500),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.grey400))),
        ]),
      );
}

class _DashboardState extends StatelessWidget {
  const _DashboardState(
      {required this.icon,
      required this.title,
      required this.message,
      required this.onRetry});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        key: const Key('lgu-dashboard-error-state'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.grey500, size: 42),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey400)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry')),
          ]),
        ),
      );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
        key: const Key('lgu-dashboard-skeleton'),
        padding: const EdgeInsets.all(24),
        children: [
          Container(height: 32, width: 340, decoration: _box()),
          const SizedBox(height: 20),
          Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                  8,
                  (_) =>
                      Container(width: 240, height: 126, decoration: _box()))),
          const SizedBox(height: 20),
          Container(height: 240, decoration: _box()),
        ],
      );
  static BoxDecoration _box() => BoxDecoration(
      color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(14));
}
