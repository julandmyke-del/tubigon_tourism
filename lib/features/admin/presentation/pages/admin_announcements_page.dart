import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../notifications/repositories/notification_repository.dart';
import '../../../connected_operations/data/connected_operations_repository.dart';
import '../../providers/admin_providers.dart';

class AdminAnnouncementsPage extends ConsumerStatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  ConsumerState<AdminAnnouncementsPage> createState() =>
      _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState
    extends ConsumerState<AdminAnnouncementsPage> {
  String _status = 'all';
  String _audience = 'all';

  void _refresh() {
    ref.invalidate(adminAnnouncementsProvider);
    ref.invalidate(touristNotificationsProvider);
    ref.invalidate(touristUnreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminAnnouncementsProvider);
    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 620,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Broadcast Announcements',
                            style: AppTypography.headlineMedium.copyWith(
                                color: AdminColors.textPrimary,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'Create, schedule, publish, and archive role-targeted municipal notices.',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AdminColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _compose(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Announcement'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AdminColors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _filter(
                    value: _status,
                    label: 'Status',
                    values: const [
                      'all',
                      'draft',
                      'scheduled',
                      'published',
                      'expired',
                      'archived'
                    ],
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  _filter(
                    value: _audience,
                    label: 'Audience',
                    values: const [
                      'all',
                      'everyone',
                      'tourist',
                      'msme_owner',
                      'tourism_partner',
                      'lgu_staff',
                      'admin'
                    ],
                    onChanged: (v) => setState(() => _audience = v),
                  ),
                  IconButton.outlined(
                    onPressed: _refresh,
                    tooltip: 'Refresh announcements',
                    icon: const Icon(Icons.refresh_rounded,
                        color: AdminColors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: value.when(
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AdminColors.orange)),
                  error: (_, __) => _Error(onRetry: _refresh),
                  data: (items) {
                    final filtered = items.where((item) {
                      final status = (item['effective_status'] ??
                              item['status'] ??
                              'draft')
                          .toString();
                      return (_status == 'all' || status == _status) &&
                          (_audience == 'all' ||
                              (item['audiences'] is List &&
                                  (item['audiences'] as List).contains(
                                      _audience == 'everyone'
                                          ? 'public'
                                          : _audience)) ||
                              item['audience'] == _audience);
                    }).toList();
                    if (filtered.isEmpty) {
                      return const _Empty();
                    }
                    return LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1050 ? 2 : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 220,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) => _AnnouncementCard(
                          item: filtered[index],
                          onPreview: () => _preview(filtered[index]),
                          onEdit: () => _compose(existing: filtered[index]),
                          onPublish: () => _publish(filtered[index]),
                          onUnpublish: () => _unpublish(filtered[index]),
                          onArchive: () => _archive(filtered[index]),
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filter({
    required String value,
    required String label,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AdminColors.navy900,
          border: Border.all(color: AdminColors.cardBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: AdminColors.navy900,
            style: TextStyle(color: AdminColors.textPrimary),
            items: values
                .map((item) => DropdownMenuItem(
                    value: item, child: Text('$label: ${_label(item)}')))
                .toList(),
            onChanged: (item) => item == null ? null : onChanged(item),
          ),
        ),
      );

  Future<void> _compose({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ComposeDialog(existing: existing),
    );
    if (!mounted || saved != true) return;
    _refresh();
    _message(
        existing == null ? 'Announcement saved.' : 'Announcement updated.');
  }

  void _preview(Map<String, dynamic> item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: Text(item['title']?.toString() ?? 'Announcement',
            style: TextStyle(color: AdminColors.textPrimary)),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['body']?.toString() ?? '',
                    style: TextStyle(color: AdminColors.textSecondary)),
                const SizedBox(height: 16),
                Text('Approximate placements',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final placement in const [
                  ('Mobile banner', Icons.smartphone),
                  ('Web carousel card', Icons.web),
                  ('Notification item', Icons.notifications_outlined),
                ])
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.cardBorder),
                    ),
                    child: Row(children: [
                      Icon(placement.$2, color: AdminColors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(placement.$1,
                                style: TextStyle(
                                    color: AdminColors.textMuted,
                                    fontSize: 11)),
                            Text(item['title']?.toString() ?? 'Announcement',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AdminColors.textPrimary,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _publish(Map<String, dynamic> item) async {
    try {
      await ref.read(adminRepositoryProvider).manageAnnouncement({
        'status': 'published',
        'starts_at': DateTime.now().toUtc().toIso8601String(),
      }, id: item['id'].toString());
      if (!mounted) return;
      _refresh();
      _message('Announcement published.');
    } catch (_) {
      if (mounted) _message('Unable to publish announcement.', error: true);
    }
  }

  Future<void> _unpublish(Map<String, dynamic> item) async {
    try {
      await ref.read(adminRepositoryProvider).manageAnnouncement(
        {'status': 'draft'},
        id: item['id'].toString(),
      );
      if (!mounted) return;
      _refresh();
      _message('Announcement moved to drafts.');
    } catch (_) {
      if (mounted) _message('Unable to unpublish announcement.', error: true);
    }
  }

  Future<void> _archive(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: Text('Archive announcement?',
            style: TextStyle(color: AdminColors.textPrimary)),
        content: Text(item['title']?.toString() ?? '',
            style: TextStyle(color: AdminColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Archive')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .deleteAnnouncement(item['id'].toString());
      if (!mounted) return;
      _refresh();
      _message('Announcement archived.');
    } catch (_) {
      if (mounted) _message('Unable to archive announcement.', error: true);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AdminColors.danger : AdminColors.success,
    ));
  }
}

class _ComposeDialog extends ConsumerStatefulWidget {
  const _ComposeDialog({this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends ConsumerState<_ComposeDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _cta;
  late String _type;
  late Set<String> _audiences;
  late String _priority;
  late String _displayType;
  DateTime? _start;
  DateTime? _expiry;
  String? _relatedType;
  String? _relatedId;
  Future<List<Map<String, dynamic>>>? _relatedOptions;
  XFile? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _title = TextEditingController(text: item?['title']?.toString());
    _body = TextEditingController(text: item?['body']?.toString());
    _cta = TextEditingController(text: item?['cta_label']?.toString());
    _type = item?['type']?.toString() ?? 'general';
    final existingAudiences = item?['audiences'];
    _audiences = existingAudiences is List
        ? existingAudiences.map((e) => e.toString()).toSet()
        : {
            item?['audience'] == 'everyone'
                ? 'public'
                : item?['audience']?.toString() ?? 'public'
          };
    _priority = item?['priority']?.toString() ?? 'normal';
    _displayType = item?['display_type']?.toString() ?? 'notification';
    _start = DateTime.tryParse(item?['starts_at']?.toString() ?? '')?.toLocal();
    _expiry =
        DateTime.tryParse(item?['expires_at']?.toString() ?? '')?.toLocal();
    _relatedType = item?['related_type']?.toString();
    _relatedId = item?['related_id']?.toString();
    if (_relatedType != null) {
      _relatedOptions = ref
          .read(connectedOperationsRepositoryProvider)
          .announcementRelatedOptions(_relatedType!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _cta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: Text(
            widget.existing == null
                ? 'Create Announcement'
                : 'Edit Announcement',
            style: TextStyle(color: AdminColors.textPrimary)),
        content: SizedBox(
          width: 680,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _field(_title, 'Title', 255),
                  const SizedBox(height: 12),
                  _field(_body, 'Message', 10000, lines: 5),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    _dropdown(
                        'Type',
                        _type,
                        const [
                          'general',
                          'advisory',
                          'event',
                          'safety',
                          'service',
                          'system'
                        ],
                        (v) => setState(() => _type = v)),
                    _dropdown(
                        'Priority',
                        _priority,
                        const ['normal', 'important', 'urgent'],
                        (v) => setState(() => _priority = v)),
                    _dropdown(
                        'Display',
                        _displayType,
                        const [
                          'notification',
                          'banner',
                          'carousel',
                          'pinned',
                          'urgent_alert'
                        ],
                        (v) => setState(() => _displayType = v)),
                  ]),
                  const SizedBox(height: 12),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          'public',
                          'tourist',
                          'msme_owner',
                          'tourism_partner',
                          'lgu_staff',
                          'admin'
                        ]
                            .map((role) => FilterChip(
                                  label: Text(_label(role)),
                                  selected: _audiences.contains(role),
                                  onSelected: _saving
                                      ? null
                                      : (selected) => setState(() => selected
                                          ? _audiences.add(role)
                                          : _audiences.remove(role)),
                                ))
                            .toList(),
                      )),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pick(start: true),
                      icon: const Icon(Icons.schedule),
                      label: Text(_start == null
                          ? 'Start date/time'
                          : DateFormat('MMM d, y h:mm a').format(_start!)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pick(start: false),
                      icon: const Icon(Icons.event_busy),
                      label: Text(_expiry == null
                          ? 'No expiry'
                          : DateFormat('MMM d, y h:mm a').format(_expiry!)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cta,
                    enabled: !_saving,
                    maxLength: 80,
                    decoration: const InputDecoration(
                        labelText: 'Call-to-action label (optional)'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _relatedType,
                    decoration:
                        const InputDecoration(labelText: 'Related content'),
                    items: const [
                      'tourist_spot',
                      'ferry_schedule',
                      'msme',
                      'eco_tip',
                      'emergency_advisory',
                    ]
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text(_label(value))))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                              _relatedType = value;
                              _relatedId = null;
                              _relatedOptions = value == null
                                  ? null
                                  : ref
                                      .read(
                                          connectedOperationsRepositoryProvider)
                                      .announcementRelatedOptions(value);
                            }),
                  ),
                  if (_relatedOptions != null)
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _relatedOptions,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const LinearProgressIndicator();
                        }
                        final options = snapshot.data ?? const [];
                        if (options.isEmpty) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('No available records for this type.'),
                          );
                        }
                        final valid = options.any(
                            (item) => item['id']?.toString() == _relatedId);
                        return DropdownButtonFormField<String>(
                          initialValue: valid ? _relatedId : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Related record'),
                          items: options
                              .map((item) => DropdownMenuItem(
                                    value: item['id'].toString(),
                                    child: Text(
                                      _announcementRelatedLabel(item),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _relatedId = value),
                        );
                      },
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(_image?.name ??
                        (widget.existing?['image_url'] != null
                            ? 'Current announcement image'
                            : 'Add optional image')),
                    subtitle: const Text('JPEG, PNG, or WebP up to 5 MB'),
                    onTap: _saving
                        ? null
                        : () async {
                            final image = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 88,
                              maxWidth: 1920,
                            );
                            if (image != null && mounted) {
                              setState(() => _image = image);
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: _saving ? null : _previewDraft,
              child: const Text('Preview')),
          TextButton(
              onPressed: _saving ? null : () => _save('draft'),
              child: const Text('Save Draft')),
          if (_start != null && _start!.isAfter(DateTime.now()))
            OutlinedButton(
                onPressed: _saving ? null : () => _save('scheduled'),
                child: const Text('Schedule')),
          FilledButton(
            onPressed: _saving ? null : () => _save('published'),
            style: FilledButton.styleFrom(backgroundColor: AdminColors.orange),
            child: Text(_saving ? 'Saving...' : 'Publish Now'),
          ),
        ],
      );

  Future<void> _previewDraft() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AdminColors.navy900,
        title: Text(
          _title.text.trim().isEmpty
              ? 'Announcement title'
              : _title.text.trim(),
          style: TextStyle(color: AdminColors.textPrimary),
        ),
        content: SizedBox(
          width: 520,
          child: Card(
            color: _priority == 'urgent'
                ? AdminColors.danger.withValues(alpha: .35)
                : AdminColors.cardBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_label(_priority)} · ${_label(_displayType)}',
                      style: const TextStyle(color: AdminColors.orange)),
                  const SizedBox(height: 8),
                  Text(
                    _body.text.trim().isEmpty
                        ? 'Announcement message preview'
                        : _body.text.trim(),
                    style: TextStyle(color: AdminColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, int max,
          {int lines = 1}) =>
      TextFormField(
        controller: controller,
        enabled: !_saving,
        maxLength: max,
        maxLines: lines,
        style: TextStyle(color: AdminColors.textPrimary),
        decoration: InputDecoration(labelText: label),
        validator: (value) => value == null || value.trim().isEmpty
            ? '$label is required.'
            : null,
      );

  Widget _dropdown(String label, String value, List<String> values,
          ValueChanged<String> changed) =>
      SizedBox(
        width: 190,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AdminColors.navy900,
          decoration: InputDecoration(labelText: label),
          style: TextStyle(color: AdminColors.textPrimary),
          items: values
              .map((v) => DropdownMenuItem(value: v, child: Text(_label(v))))
              .toList(),
          onChanged: _saving ? null : (v) => v == null ? null : changed(v),
        ),
      );

  Future<void> _pick({required bool start}) async {
    final current = (start ? _start : _expiry) ??
        DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (!mounted || time == null) return;
    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => start ? _start = selected : _expiry = selected);
  }

  Future<void> _save(String status) async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    if (_audiences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one audience.')));
      return;
    }
    if (_expiry != null && _start != null && !_expiry!.isAfter(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Expiry must be after the start time.')));
      return;
    }
    if (_relatedType != null && _relatedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select the related record or clear its type.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).manageAnnouncement({
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'category': _type,
        'type': _type,
        'audiences': _audiences.toList(),
        'priority': _priority,
        'display_type': _displayType,
        'status': status,
        'starts_at': status == 'published'
            ? DateTime.now().toUtc().toIso8601String()
            : _start?.toUtc().toIso8601String(),
        'expires_at': _expiry?.toUtc().toIso8601String(),
        'cta_label': _cta.text.trim().isEmpty ? null : _cta.text.trim(),
        'related_type': _relatedType,
        'related_id': _relatedId,
      },
          id: widget.existing?['id']?.toString(),
          image: await _image?.readAsBytes(),
          imageName: _image?.name);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'The announcement could not be saved. Check the dates and fields.')));
    }
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard(
      {required this.item,
      required this.onPreview,
      required this.onEdit,
      required this.onPublish,
      required this.onUnpublish,
      required this.onArchive});
  final Map<String, dynamic> item;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final status =
        (item['effective_status'] ?? item['status'] ?? 'draft').toString();
    final priority = (item['priority'] ?? 'normal').toString();
    return Card(
      color: AdminColors.cardBg,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: AdminColors.cardBorder),
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(item['title']?.toString() ?? 'Untitled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold))),
            _Badge(status, AdminColors.info),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            _Badge(_label(item['audience']?.toString() ?? 'everyone'),
                AdminColors.orange),
            _Badge(
                _label(priority),
                priority == 'urgent'
                    ? AdminColors.danger
                    : AdminColors.warning),
          ]),
          const SizedBox(height: 10),
          Expanded(
              child: Text(item['body']?.toString() ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AdminColors.textSecondary, height: 1.4))),
          Wrap(spacing: 4, children: [
            TextButton(onPressed: onPreview, child: const Text('Preview')),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
            if (status == 'draft' || status == 'scheduled')
              TextButton(onPressed: onPublish, child: const Text('Publish')),
            if (status == 'published')
              TextButton(
                  onPressed: onUnpublish, child: const Text('Unpublish')),
            TextButton(
                onPressed: status == 'archived' ? null : onArchive,
                child: const Text('Archive',
                    style: TextStyle(color: AdminColors.danger))),
          ]),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20)),
        child: Text(_label(text),
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.campaign_outlined, size: 48, color: AdminColors.textMuted),
        const SizedBox(height: 10),
        Text('No announcements match these filters.',
            style: TextStyle(color: AdminColors.textSecondary)),
      ]));
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry announcements')));
}

String _label(String value) => value
    .split('_')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _announcementRelatedLabel(Map<String, dynamic> item) {
  final name = item['name'] ?? item['title'] ?? item['route'];
  final reference = item['public_reference'] ?? item['reference_no'];
  return (name ?? reference ?? 'Related record').toString();
}
