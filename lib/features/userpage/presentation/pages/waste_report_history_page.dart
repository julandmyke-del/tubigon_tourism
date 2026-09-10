import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../waste_reporting/repositories/waste_report_repository.dart';
import '../../../authentication/auth_provider.dart';
import '../../../../core/utils/auth_action_guard.dart';

class WasteReportHistoryPage extends ConsumerWidget {
  const WasteReportHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      return signedInRequiredPage(context, ref, title: 'My Waste Reports');
    }
    final reports = ref.watch(myWasteReportsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        title: Text(context.tr('my_waste_reports')),
        actions: [
          IconButton(
            tooltip: 'Create report',
            onPressed: () => context.push('/waste-report'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _StateMessage(
          icon: Icons.cloud_off_rounded,
          message:
              'Unable to load your reports. Check your connection and retry.',
          onRetry: () => ref.invalidate(myWasteReportsProvider),
        ),
        data: (items) => items.isEmpty
            ? _StateMessage(
                icon: Icons.cleaning_services_outlined,
                message: 'You have not submitted a waste report yet.',
                onRetry: () => context.push('/waste-report'),
                action: 'Create Report',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myWasteReportsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _ReportCard(report: items[index]),
                ),
              ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final WasteReportRecord report;

  @override
  Widget build(BuildContext context) {
    final color = switch (report.status) {
      'resolved' || 'closed' => const Color(0xFF34D399),
      'rejected' => const Color(0xFFF87171),
      'in_progress' || 'assigned' || 'under_review' => const Color(0xFF38BDF8),
      _ => const Color(0xFFF59E0B),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(_label(report.category),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(20)),
            child: Text(_label(report.status),
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('${report.reference} · ${_label(report.severity)} severity',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 8),
        Text(report.description,
            style: const TextStyle(color: Color(0xFFCBD5E1))),
        if (report.resolvedAddress?.isNotEmpty == true ||
            report.locationDescription?.isNotEmpty == true ||
            report.barangay?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            [
              report.resolvedAddress,
              report.locationDescription,
              report.barangay
            ].where((value) => value?.isNotEmpty == true).join(' • '),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          report.createdAt == null
              ? 'Submission time unavailable'
              : 'Submitted ${DateFormat.yMMMd().add_jm().format(report.createdAt!.toLocal())}',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
        if (report.images.isNotEmpty || report.media.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Row(children: [
            Icon(Icons.photo_rounded, size: 15, color: Color(0xFF38BDF8)),
            SizedBox(width: 5),
            Text('Evidence attached',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ]),
        ],
        if (report.resolutionSummary?.isNotEmpty == true) ...[
          const Divider(height: 22),
          Text('Action Taken: ${report.resolutionSummary}',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
          if (report.status == 'resolved' || report.status == 'closed')
            const Text('Resolved ✓',
                style: TextStyle(
                    color: Color(0xFF34D399), fontWeight: FontWeight.w800)),
        ],
        if (report.history.isNotEmpty) ...[
          const Divider(height: 22),
          Text(context.tr('status_history'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final entry in report.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• ${_label(entry['to_status']?.toString() ?? '')}'
                '${entry['notes']?.toString().isNotEmpty == true ? ': ${entry['notes']}' : ''}'
                '${entry['created_at'] != null ? ' · ${_date(entry['created_at'])}' : ''}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
        ],
      ]),
    );
  }

  static String _label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? ''
        : DateFormat.yMMMd().add_jm().format(parsed.toLocal());
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.message,
    required this.onRetry,
    this.action = 'Retry',
  });
  final IconData icon;
  final String message;
  final VoidCallback onRetry;
  final String action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 54, color: const Color(0xFF64748B)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFCBD5E1))),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: Text(action)),
          ]),
        ),
      );
}
