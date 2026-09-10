import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/exceptions/app_exception.dart';
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
        title: const Text('Waste Report Detail'),
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
            onRetry: () =>
                ref.invalidate(lguWasteReportProvider(widget.reportId))),
        data: _body,
      ),
    );
  }

  Widget _body(Map<String, dynamic> item) {
    final reporter = item['user'];
    final media = (item['media'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    final history = (item['history'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    final id = item['id']?.toString() ?? widget.reportId;
    return RefreshIndicator(
      onRefresh: () async =>
          ref.refresh(lguWasteReportProvider(widget.reportId).future),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        _section('Report', [
          _row(
              'Reference',
              item['report_reference'] ??
                  'WR-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}'),
          _row('Reporter', reporter is Map ? reporter['name'] : 'Reporter'),
          _row('Category', _categoryName(item)),
          _row('Severity', _label(item['severity'] ?? item['priority'])),
          _row('Description', item['description']),
          _row('Submitted', _date(item['submitted_at'] ?? item['created_at'])),
        ]),
        const SizedBox(height: 12),
        _section('Location', [
          _row('Resolved address', item['resolved_address']),
          _row('Landmark', item['location_description']),
          _row('Barangay', item['barangay']),
          _row('Coordinates', '${item['latitude']}, ${item['longitude']}'),
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/map?marker=waste_report:${item['id']}'),
            icon: const Icon(Icons.map_rounded),
            label: const Text('Open on Waste Map'),
          ),
        ]),
        const SizedBox(height: 12),
        _section('Operations', [
          _row('Status', _label(item['status'])),
          _row('Assignment', item['assigned_personnel']),
          _row('Assigned at', _date(item['assigned_at'])),
          _row('Internal LGU note', item['lgu_notes']),
          _row('Public action taken', item['resolution_summary']),
          _row('Resolved at', _date(item['resolved_at'])),
        ]),
        const SizedBox(height: 12),
        _section('Authorized evidence', [
          if (media.isEmpty && (item['images'] as List?)?.isEmpty != false)
            const Text('No evidence attached.',
                style: TextStyle(color: AppColors.grey400)),
          for (final attachment in media) _mediaTile(attachment),
          for (final image in item['images'] as List? ?? const [])
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(image.toString(),
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _MediaUnavailable()),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _uploadResolutionPhoto,
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('Upload Resolution Photo'),
          ),
        ]),
        const SizedBox(height: 12),
        _section('Status history', [
          if (history.isEmpty)
            const Text('No history entries are available.',
                style: TextStyle(color: AppColors.grey400)),
          for (final entry in history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.radio_button_checked_rounded,
                  color: Color(0xFF38BDF8), size: 18),
              title: Text(
                  '${_label(entry['from_status'])} → ${_label(entry['to_status'])}',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                [entry['notes'], _date(entry['created_at'])]
                    .where((value) =>
                        value != null &&
                        value.toString().isNotEmpty &&
                        value != '—')
                    .join(' · '),
                style: const TextStyle(color: AppColors.grey400),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : () => _update(item),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Review / Assign / Resolve'),
        ),
      ]),
    );
  }

  Widget _mediaTile(Map<String, dynamic> media) {
    final type = media['media_type']?.toString() ?? 'file';
    final url = media['url']?.toString();
    if (type == 'video') {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.videocam_rounded, color: Color(0xFF38BDF8)),
        title: Text(media['original_name']?.toString() ?? 'Report video',
            style: const TextStyle(color: Colors.white)),
        subtitle: Text(_size(media['size_bytes']),
            style: const TextStyle(color: AppColors.grey400)),
      );
    }
    if (url == null || url.isEmpty) return const _MediaUnavailable();
    return FutureBuilder<Uint8List>(
      future: ref.read(lguRepositoryProvider).getAuthorizedWasteMedia(url),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) return const _MediaUnavailable();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(snapshot.data!,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _MediaUnavailable()),
          ),
        );
      },
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
          ...children,
        ]),
      );

  Widget _row(String label, Object? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
            '$label: ${value == null || value.toString().isEmpty ? '—' : value}',
            style: const TextStyle(color: AppColors.grey400)),
      );

  Future<void> _update(Map<String, dynamic> item) async {
    final current = item['status'] == 'pending'
        ? 'submitted'
        : item['status']?.toString() ?? 'submitted';
    String status = current;
    String severity = item['severity']?.toString() ?? 'moderate';
    final team = TextEditingController(
        text: item['assigned_personnel']?.toString() ?? '');
    final internal =
        TextEditingController(text: item['lgu_notes']?.toString() ?? '');
    final public = TextEditingController(
        text: item['resolution_summary']?.toString() ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Update waste operation'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Next status'),
                items: _allowedStatuses(current)
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text(_label(value))))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => status = value ?? status),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: const ['low', 'moderate', 'high', 'urgent']
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => severity = value ?? severity),
              ),
              TextField(
                  controller: team,
                  decoration:
                      const InputDecoration(labelText: 'Responsible team')),
              TextField(
                controller: internal,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Internal LGU note',
                    helperText: 'Never shown to the reporter.'),
              ),
              TextField(
                controller: public,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Public action / resolution note',
                    helperText: 'Required for resolved or rejected reports.'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (!mounted || save != true) {
      team.dispose();
      internal.dispose();
      public.dispose();
      return;
    }
    if (status == 'assigned' && team.text.trim().isEmpty) {
      _message('Choose a responsible team before assigning.');
      team.dispose();
      internal.dispose();
      public.dispose();
      return;
    }
    if (['resolved', 'rejected'].contains(status) &&
        public.text.trim().isEmpty) {
      _message('A public resolution or rejection note is required.');
      team.dispose();
      internal.dispose();
      public.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(lguRepositoryProvider).updateWasteReportStatus(
            widget.reportId,
            status,
            assignedPersonnel:
                team.text.trim().isEmpty ? null : team.text.trim(),
            severity: severity,
            internalNote:
                internal.text.trim().isEmpty ? null : internal.text.trim(),
            publicNote: public.text.trim().isEmpty ? null : public.text.trim(),
          );
      _refresh();
      if (mounted) _message('Waste report updated.', success: true);
    } catch (error) {
      if (mounted) _message(_friendly(error));
    } finally {
      team.dispose();
      internal.dispose();
      public.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadResolutionPhoto() async {
    final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 88, maxWidth: 1920);
    if (photo == null || !mounted) return;
    final extension = photo.name.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
        await photo.length() > 5 * 1024 * 1024) {
      _message('Choose a JPEG, PNG, or WebP photo no larger than 5 MB.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(lguRepositoryProvider)
          .uploadWasteResolutionPhoto(widget.reportId, photo);
      _refresh();
      if (mounted) _message('Resolution photo uploaded.', success: true);
    } catch (error) {
      if (mounted) _message(_friendly(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _refresh() {
    ref.invalidate(lguWasteReportProvider(widget.reportId));
    ref.invalidate(lguWasteReportsProvider);
    ref.invalidate(lguDashboardStatsProvider);
    ref.invalidate(lguActivityProvider);
    ref.invalidate(lguAnalyticsProvider);
    ref.invalidate(lguReportsProvider);
  }

  void _message(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? AppColors.success : AppColors.error,
      content: Text(message),
    ));
  }

  static List<String> _allowedStatuses(String current) => [
        current,
        ...switch (current) {
          'submitted' => const ['under_review', 'rejected'],
          'under_review' => const ['assigned', 'in_progress', 'rejected'],
          'assigned' => const ['in_progress', 'rejected'],
          'in_progress' => const ['resolved'],
          'resolved' => const ['closed', 'reopened'],
          'reopened' => const ['under_review'],
          _ => const <String>[],
        },
      ];

  static String _categoryName(Map<String, dynamic> item) {
    final definition = item['category_definition'];
    return definition is Map
        ? definition['name']?.toString() ?? _label(item['category'])
        : _label(item['category']);
  }

  static String _label(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '—';
    return text
        .split(RegExp('[_-]'))
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? '—'
        : DateFormat.yMMMd().add_jm().format(parsed.toLocal());
  }

  static String _size(dynamic value) {
    final bytes = int.tryParse(value?.toString() ?? '') ?? 0;
    return bytes <= 0
        ? 'Size unavailable'
        : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String _friendly(Object error) => error is AppException
      ? error.message
      : error.toString().replaceFirst('Exception: ', '');
}

class _MediaUnavailable extends StatelessWidget {
  const _MediaUnavailable();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 100,
        child: Center(
            child: Text('Evidence preview unavailable.',
                style: TextStyle(color: AppColors.grey400))),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Unable to load report — Retry'),
        ),
      );
}
