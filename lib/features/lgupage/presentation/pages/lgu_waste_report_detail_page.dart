import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguWasteReportDetailPage extends ConsumerStatefulWidget {
  const LguWasteReportDetailPage({super.key, required this.reportId});
  final String reportId;
  @override
  ConsumerState<LguWasteReportDetailPage> createState() => _State();
}

class _State extends ConsumerState<LguWasteReportDetailPage> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final report = ref.watch(lguWasteReportProvider(widget.reportId));
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
          backgroundColor: const Color(0xFF1C2541),
          leading: BackButton(onPressed: () => context.pop()),
          title: const Text('Waste Report Detail')),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
            child: OutlinedButton(
                onPressed: () =>
                    ref.invalidate(lguWasteReportProvider(widget.reportId)),
                child: Text('Retry: $error'))),
        data: (item) {
          final reporter = item['user'];
          final images = item['images'] as List? ?? const [];
          return ListView(padding: const EdgeInsets.all(24), children: [
            _section('Report', [
              _row('Report ID', item['id']),
              _row('Category', item['category']),
              _row('Description', item['description']),
              _row('Landmark', item['location_description']),
              _row('Submitted', item['created_at']),
              _row('Reporter', reporter is Map ? reporter['name'] : 'Reporter'),
            ]),
            const SizedBox(height: 12),
            _section('Operations', [
              _row('Status', item['status']),
              _row('Priority', item['priority']),
              _row('Assignment', item['assigned_personnel']),
              _row('Assigned at', item['assigned_at']),
              _row('LGU notes', item['lgu_notes']),
              _row('Resolved at', item['resolved_at']),
            ]),
            const SizedBox(height: 12),
            _section('Evidence and location', [
              _row('Coordinates', '${item['latitude']}, ${item['longitude']}'),
              _row('Photos', '${images.length} attachment(s)'),
              OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/map?marker=waste:${item['id']}'),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Open on Smart Map')),
            ]),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: _saving ? null : () => _update(item),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Update operations state')),
          ]);
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const Divider(),
          ...children
        ]),
      );
  Widget _row(String label, Object? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: ${value ?? '—'}',
          style: const TextStyle(color: AppColors.grey400)));

  Future<void> _update(Map<String, dynamic> item) async {
    String status = item['status'] == 'pending'
        ? 'submitted'
        : item['status']?.toString() ?? 'submitted';
    String priority = item['priority']?.toString() ?? 'normal';
    final team = TextEditingController(
        text: item['assigned_personnel']?.toString() ?? '');
    final notes =
        TextEditingController(text: item['lgu_notes']?.toString() ?? '');
    final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Update waste operation'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                        initialValue: status,
                        items: const [
                          DropdownMenuItem(
                              value: 'submitted', child: Text('Submitted')),
                          DropdownMenuItem(
                              value: 'under_review',
                              child: Text('Under review')),
                          DropdownMenuItem(
                              value: 'assigned', child: Text('Assigned')),
                          DropdownMenuItem(
                              value: 'in_progress', child: Text('In progress')),
                          DropdownMenuItem(
                              value: 'resolved', child: Text('Resolved')),
                          DropdownMenuItem(
                              value: 'closed', child: Text('Closed')),
                          DropdownMenuItem(
                              value: 'rejected', child: Text('Rejected')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => status = value ?? status)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        initialValue: priority,
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(
                              value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(
                              value: 'urgent', child: Text('Urgent')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => priority = value ?? priority)),
                    TextField(
                        controller: team,
                        decoration: const InputDecoration(
                            labelText: 'Responsible team')),
                    TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'LGU notes')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Save'))
                  ],
                )));
    if (!mounted || save != true) {
      team.dispose();
      notes.dispose();
      return;
    }
    if (status == 'assigned' && team.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose a responsible team before assigning.')));
      team.dispose();
      notes.dispose();
      return;
    }
    if (['resolved', 'rejected'].contains(status) &&
        notes.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A resolution or rejection note is required.')));
      team.dispose();
      notes.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(lguRepositoryProvider).updateWasteReportStatus(
          widget.reportId, status,
          remarks: notes.text.trim().isEmpty ? null : notes.text.trim(),
          assignedPersonnel: team.text.trim().isEmpty ? null : team.text.trim(),
          priority: priority);
      if (!mounted) return;
      ref.invalidate(lguWasteReportProvider(widget.reportId));
      ref.invalidate(lguWasteReportsProvider);
      ref.invalidate(lguDashboardStatsProvider);
      ref.invalidate(lguActivityProvider);
      ref.invalidate(lguAnalyticsProvider);
      ref.invalidate(lguReportsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Waste report updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.error, content: Text(error.toString())));
      }
    } finally {
      team.dispose();
      notes.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }
}
