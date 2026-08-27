import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../msme_theme.dart';

class MsmePortalReportsPage extends ConsumerWidget {
  const MsmePortalReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Reports & Data Exports',
                style: MsmeTheme.headingLarge()),
            Text(
              'Export official booking records, financial breakdowns, and customer feedback reports.',
              style: MsmeTheme.body(color: MsmeTheme.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.5,
                children: [
                  _ReportCard(
                    title: 'Reservation & Booking Log',
                    description:
                        'Complete breakdown of all guest reservations, status changes, and gross booking volume.',
                    icon: Icons.calendar_month_rounded,
                    color: MsmeTheme.blue,
                    onExport: (fmt) =>
                        _showExportSnackbar(context, 'Reservation Log', fmt),
                  ),
                  _ReportCard(
                    title: 'Business Performance Summary',
                    description:
                        'Monthly revenue metrics, listing occupancy rates, and sales performance indicators.',
                    icon: Icons.assessment_rounded,
                    color: MsmeTheme.green,
                    onExport: (fmt) => _showExportSnackbar(
                        context, 'Performance Summary', fmt),
                  ),
                  _ReportCard(
                    title: 'Visitor & Traffic Demographics',
                    description:
                        'Tourist influx trends, peak visiting hours, and geographical visitor distribution.',
                    icon: Icons.groups_rounded,
                    color: MsmeTheme.purple,
                    onExport: (fmt) => _showExportSnackbar(
                        context, 'Visitor Demographics', fmt),
                  ),
                  _ReportCard(
                    title: 'Customer Review & Rating Report',
                    description:
                        'Compiled review feedback, average rating trajectory, and feedback sentiment analysis.',
                    icon: Icons.rate_review_rounded,
                    color: MsmeTheme.amber,
                    onExport: (fmt) =>
                        _showExportSnackbar(context, 'Customer Reviews', fmt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportSnackbar(BuildContext context, String title, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: MsmeTheme.green,
        content: Text('Exporting "$title" as $format... Download starting.'),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Function(String format) onExport;

  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: MsmeTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                      color: MsmeTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          Text(description,
              style: GoogleFonts.inter(
                  color: MsmeTheme.textMuted, fontSize: 13, height: 1.4)),
          Row(
            children: [
              Text('Export format:',
                  style: GoogleFonts.inter(
                      color: MsmeTheme.textSubtle, fontSize: 12)),
              const Spacer(),
              _ExportChip(
                  label: 'PDF',
                  color: MsmeTheme.redLight,
                  onTap: () => onExport('PDF')),
              const SizedBox(width: 6),
              _ExportChip(
                  label: 'EXCEL',
                  color: MsmeTheme.greenLight,
                  onTap: () => onExport('Excel')),
              const SizedBox(width: 6),
              _ExportChip(
                  label: 'CSV',
                  color: MsmeTheme.blueLight,
                  onTap: () => onExport('CSV')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExportChip(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
