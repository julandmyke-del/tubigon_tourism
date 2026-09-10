import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../eco/repositories/eco_repository.dart';
import '../../providers/lgu_providers.dart';

class LguEcoTipsPage extends ConsumerStatefulWidget {
  const LguEcoTipsPage({super.key});
  @override
  ConsumerState<LguEcoTipsPage> createState() => _LguEcoTipsPageState();
}

class _LguEcoTipsPageState extends ConsumerState<LguEcoTipsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(lguEcoTipsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Eco Tip'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Eco-Tourism Guidance',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800)),
          const Text(
              'Create, schedule, publish, and archive practical visitor guidance.',
              style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
                labelText: 'Search guidance',
                prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: tips.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: OutlinedButton.icon(
                  onPressed: () => ref.invalidate(lguEcoTipsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Unable to load eco tips. Retry'),
                ),
              ),
              data: (items) {
                final filtered = items
                    .where((item) =>
                        '${item['title'] ?? ''} ${item['short_message'] ?? ''} ${item['content'] ?? ''}'
                            .toLowerCase()
                            .contains(_query))
                    .toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No eco tips match this view.',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(lguEcoTipsProvider.future),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final item = filtered[index];
                      final published = item['is_published'] == true ||
                          item['is_published'] == 1;
                      return Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2541),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.eco_rounded,
                              color: Color(0xFF34D399)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      item['title']?.toString() ??
                                          'Eco guidance',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                      item['short_message']?.toString() ??
                                          item['content']?.toString() ??
                                          '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFFCBD5E1))),
                                  Text(
                                    '${_label(item['category']?.toString() ?? 'general')} • ${item['spot'] is Map ? item['spot']['name'] ?? 'General' : 'General'}',
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                ]),
                          ),
                          Chip(label: Text(published ? 'Published' : 'Draft')),
                          IconButton(
                            tooltip: 'Edit eco tip',
                            onPressed: () => _showEditor(existing: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Archive eco tip',
                            onPressed: () => _archive(item),
                            icon: const Icon(Icons.archive_outlined,
                                color: Colors.redAccent),
                          ),
                        ]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _showEditor({Map<String, dynamic>? existing}) async {
    final spots = await ref.read(lguTouristSpotsProvider.future);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EcoTipDialog(
        existing: existing,
        spots: spots,
        onSaved: () {
          ref.invalidate(lguEcoTipsProvider);
          ref.invalidate(ecoTipsListProvider);
        },
      ),
    );
  }

  Future<void> _archive(Map<String, dynamic> item) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive eco tip?'),
        content: const Text('It will no longer be visible to tourists.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive Eco Tip')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await ref
          .read(lguRepositoryProvider)
          .archiveEcoTip(item['id'].toString());
      ref.invalidate(lguEcoTipsProvider);
      ref.invalidate(ecoTipsListProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to archive eco tip: $error')));
      }
    }
  }

  static String _label(String value) => value
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _EcoTipDialog extends ConsumerStatefulWidget {
  const _EcoTipDialog(
      {required this.existing, required this.spots, required this.onSaved});
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> spots;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EcoTipDialog> createState() => _EcoTipDialogState();
}

class _EcoTipDialogState extends ConsumerState<_EcoTipDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _short;
  late final TextEditingController _content;
  late final TextEditingController _priority;
  late String _category;
  late String _language;
  String? _spotId;
  late bool _published;
  late bool _active;
  DateTime? _starts;
  DateTime? _ends;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.existing ?? const <String, dynamic>{};
    _title = TextEditingController(text: value['title']?.toString());
    _short = TextEditingController(text: value['short_message']?.toString());
    _content = TextEditingController(text: value['content']?.toString());
    _priority =
        TextEditingController(text: value['priority']?.toString() ?? '0');
    _category = value['category']?.toString() ?? 'general';
    _language = value['language']?.toString() ?? 'en';
    _spotId = value['spot_id']?.toString();
    _published = value['is_published'] == true || value['is_published'] == 1;
    _active = value['is_active'] == null ||
        value['is_active'] == true ||
        value['is_active'] == 1;
    _starts = DateTime.tryParse(value['starts_at']?.toString() ?? '');
    _ends = DateTime.tryParse(value['ends_at']?.toString() ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _short.dispose();
    _content.dispose();
    _priority.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.existing == null ? 'Create Eco Tip' : 'Edit Eco Tip'),
        content: SizedBox(
          width: 620,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Use at least 3 characters.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _short,
                  maxLength: 500,
                  decoration: const InputDecoration(
                      labelText: 'Short message',
                      helperText:
                          'A concise instruction shown before details.'),
                ),
                TextFormField(
                  controller: _content,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 5000,
                  decoration:
                      const InputDecoration(labelText: 'Detailed guidance *'),
                  validator: (value) => (value?.trim().length ?? 0) < 10
                      ? 'Provide at least 10 meaningful characters.'
                      : null,
                ),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        'general',
                        'marine',
                        'waste',
                        'nature',
                        'wildlife',
                        'community',
                        'resources',
                        'transport'
                      ]
                          .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_LguEcoTipsPageState._label(value))))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _category = value!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: const InputDecoration(labelText: 'Language'),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ceb', child: Text('Cebuano')),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _language = value!),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: widget.spots
                          .any((spot) => spot['id']?.toString() == _spotId)
                      ? _spotId
                      : null,
                  decoration:
                      const InputDecoration(labelText: 'Related destination'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('General guidance')),
                    ...widget.spots.map((spot) => DropdownMenuItem<String?>(
                        value: spot['id']?.toString(),
                        child: Text(spot['name']?.toString() ??
                            'Unnamed destination'))),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _spotId = value),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priority,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration:
                          const InputDecoration(labelText: 'Priority (0–100)'),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        return parsed == null || parsed < 0 || parsed > 100
                            ? 'Use a value from 0 to 100.'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: SwitchListTile(
                          value: _published,
                          title: const Text('Published'),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _published = value))),
                  Expanded(
                      child: SwitchListTile(
                          value: _active,
                          title: const Text('Active'),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _active = value))),
                ]),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _pickDate(true),
                          icon: const Icon(Icons.event_available_rounded),
                          label: Text(_starts == null
                              ? 'No start date'
                              : 'Starts ${DateFormat.yMMMd().format(_starts!)}'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _pickDate(false),
                          icon: const Icon(Icons.event_busy_rounded),
                          label: Text(_ends == null
                              ? 'No end date'
                              : 'Ends ${DateFormat.yMMMd().format(_ends!)}'))),
                ]),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Eco Tip')),
        ],
      );

  Future<void> _pickDate(bool start) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final initial = start ? _starts : _ends;
    final value = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 1095)),
        initialDate: initial == null || initial.isBefore(now) ? now : initial);
    if (value == null || !mounted) return;
    setState(() => start
        ? _starts = value
        : _ends = value.add(const Duration(hours: 23, minutes: 59)));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_starts != null && _ends != null && _ends!.isBefore(_starts!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('End date must be on or after the start date.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(lguRepositoryProvider).saveEcoTip({
        'title': _title.text.trim(),
        'short_message': _short.text.trim().isEmpty ? null : _short.text.trim(),
        'content': _content.text.trim(),
        'category': _category,
        'spot_id': _spotId,
        'language': _language,
        'priority': int.parse(_priority.text),
        'is_published': _published,
        'is_active': _active,
        'starts_at': _starts?.toIso8601String(),
        'ends_at': _ends?.toIso8601String(),
      }, id: widget.existing?['id']?.toString());
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to save eco tip: $error')));
        setState(() => _saving = false);
      }
    }
  }
}
