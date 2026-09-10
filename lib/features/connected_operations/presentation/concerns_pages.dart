import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/localization/app_localization.dart';
import '../data/connected_operations_repository.dart';

class ConcernsPage extends ConsumerWidget {
  const ConcernsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concerns = ref.watch(myConcernsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(title: Text(context.tr('concerns_support'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _submit(context, ref),
        icon: const Icon(Icons.add_comment),
        label: Text(context.tr('submit_concern')),
      ),
      body: concerns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(myConcernsProvider),
            child: Text(context.tr('retry')),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(child: Text(context.tr('no_concerns')))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myConcernsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      color: const Color(0xFF111C2F),
                      child: ListTile(
                        leading: const Icon(Icons.support_agent,
                            color: Color(0xFFF59E0B)),
                        title: Text(item['subject']?.toString() ??
                            context.tr('concern')),
                        subtitle: Text(
                          '${item['reference_no'] ?? ''} · ${item['category'] is Map ? (item['category'] as Map)['name'] ?? '' : ''}\n${_label(item['status'])} · ${item['created_at']?.toString().split('T').first ?? ''}',
                        ),
                        isThreeLine: true,
                        onTap: () => _detail(
                          context,
                          ref,
                          item['id'].toString(),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(connectedOperationsRepositoryProvider);
    List<Map<String, dynamic>> categories;
    try {
      categories = await ref.read(concernCategoriesProvider.future);
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return;
    }
    if (!context.mounted) return;
    final draft = repository.loadConcernDraft();
    String? category = draft?['category_id']?.toString() ??
        categories.firstOrNull?['id']?.toString();
    if (!categories.any((item) => item['id']?.toString() == category)) {
      category = categories.firstOrNull?['id']?.toString();
    }
    final subject = TextEditingController(text: draft?['subject']?.toString());
    final details =
        TextEditingController(text: draft?['description']?.toString());
    var priority = draft?['priority']?.toString() ?? 'normal';
    String? relatedType = draft?['related_type']?.toString();
    String? relatedId = draft?['related_id']?.toString();
    final previousAttachmentName = draft?['attachment_name']?.toString();
    XFile? attachment;
    Future<List<Map<String, dynamic>>>? relatedOptions = relatedType == null
        ? null
        : repository.concernRelatedOptions(relatedType);
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('submit_concern')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration:
                        InputDecoration(labelText: context.tr('category')),
                    items: categories
                        .map((item) => DropdownMenuItem(
                              value: item['id'].toString(),
                              child: Text(_categoryLabel(context, item)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => category = value),
                  ),
                  TextField(
                    controller: subject,
                    decoration:
                        InputDecoration(labelText: context.tr('subject')),
                    maxLength: 255,
                  ),
                  TextField(
                    controller: details,
                    decoration:
                        InputDecoration(labelText: context.tr('details')),
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 10000,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration:
                        InputDecoration(labelText: context.tr('priority')),
                    items: ['low', 'normal', 'high']
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_translatedLabel(context, value)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => priority = value!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: relatedType,
                    decoration: InputDecoration(
                        labelText: context.tr('related_to_optional')),
                    items: _relatedTypes
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_translatedLabel(context, value)),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      relatedType = value;
                      relatedId = null;
                      relatedOptions = value == null
                          ? null
                          : ref
                              .read(connectedOperationsRepositoryProvider)
                              .concernRelatedOptions(value);
                    }),
                  ),
                  if (relatedOptions != null)
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: relatedOptions,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const LinearProgressIndicator();
                        }
                        final options = snapshot.data ?? const [];
                        if (options.isEmpty) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(context.tr('no_related_records')),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: relatedId,
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText: context.tr('related_record')),
                          items: options
                              .map((item) => DropdownMenuItem(
                                    value: item['id'].toString(),
                                    child: Text(
                                      _relatedLabel(item, relatedType!),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => relatedId = value),
                        );
                      },
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file),
                    title: Text(attachment?.name ??
                        previousAttachmentName ??
                        context.tr('attach_image_optional')),
                    subtitle: Text(
                        previousAttachmentName != null && attachment == null
                            ? context.tr('draft_attachment_reattach')
                            : context.tr('attachment_requirements')),
                    trailing: attachment == null
                        ? null
                        : IconButton(
                            onPressed: () =>
                                setDialogState(() => attachment = null),
                            icon: const Icon(Icons.close),
                          ),
                    onTap: () async {
                      final selected = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 88,
                        maxWidth: 2400,
                      );
                      if (selected != null) {
                        setDialogState(() => attachment = selected);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _concernGuidance(context, categories, category),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: Text(context.tr('cancel')),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'draft'),
              child: Text(context.tr('save_draft')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'submit'),
              child: Text(context.tr('submit')),
            ),
          ],
        ),
      ),
    );
    final attachmentName = attachment?.name;
    final draftAttachmentName = attachmentName ?? previousAttachmentName;
    final payload = <String, dynamic>{
      if (category != null) 'category_id': category,
      'subject': subject.text.trim(),
      'description': details.text.trim(),
      'priority': priority,
      if (relatedType != null) 'related_type': relatedType,
      if (relatedId != null) 'related_id': relatedId,
      if (draftAttachmentName != null) 'attachment_name': draftAttachmentName,
    };
    subject.dispose();
    details.dispose();
    if (action == 'draft') {
      await repository.saveConcernDraft(payload);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('draft_saved'))),
        );
      }
      return;
    }
    if (action != 'submit') return;
    if (category == null ||
        (payload['subject'] as String).length < 5 ||
        (payload['description'] as String).length < 10) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('complete_concern_details'))));
      }
      return;
    }
    payload.remove('attachment_name');
    try {
      final created = await repository.createConcern(
        payload,
        attachment: await attachment?.readAsBytes(),
        attachmentName: attachmentName,
      );
      ref.invalidate(myConcernsProvider);
      if (context.mounted) {
        await _detail(context, ref, created['id'].toString());
      }
    } on NetworkException catch (error) {
      await repository.saveConcernDraft({
        ...payload,
        if (draftAttachmentName != null) 'attachment_name': draftAttachmentName,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${context.tr('draft_saved_offline')} ${error.message}')));
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _detail(BuildContext context, WidgetRef ref, String id) async {
    Map<String, dynamic> value;
    try {
      value = await ref.read(connectedOperationsRepositoryProvider).concern(id);
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return;
    }
    if (!context.mounted) return;
    final messages = (value['messages'] as List? ?? const []).whereType<Map>();
    final histories =
        (value['histories'] as List? ?? const []).whereType<Map>();
    final attachments =
        (value['attachments'] as List? ?? const []).whereType<Map>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(value['reference_no']?.toString() ?? context.tr('concern')),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value['subject']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(value['description']?.toString() ?? ''),
                if (value['related_type'] != null)
                  Text(
                      '${context.tr('related_to')}: ${_translatedLabel(context, value['related_type'])}'),
                ...attachments.map((file) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.attach_file, size: 18),
                      title: Text(
                          file['name']?.toString() ?? context.tr('attachment')),
                      subtitle: Text(file['mime_type']?.toString() ?? ''),
                    )),
                const Divider(),
                Text(
                    '${context.tr('status')}: ${_translatedLabel(context, value['status'])}'),
                ...histories.map((history) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(_label(history['action'])),
                      subtitle: Text(history['note']?.toString() ?? ''),
                    )),
                const Divider(),
                Text(context.tr('replies'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ...messages.map((message) => ListTile(
                      dense: true,
                      title: Text(message['message']?.toString() ?? ''),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('close'))),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _reply(context, ref, id);
            },
            child: Text(context.tr('reply')),
          ),
        ],
      ),
    );
  }

  Future<void> _reply(BuildContext context, WidgetRef ref, String id) async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('reply')),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 3000,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('send'))),
        ],
      ),
    );
    final message = controller.text.trim();
    controller.dispose();
    if (accepted == true && message.isNotEmpty) {
      try {
        await ref
            .read(connectedOperationsRepositoryProvider)
            .replyConcern(id, message);
        ref.invalidate(myConcernsProvider);
      } catch (error) {
        if (context.mounted) _showError(context, error);
      }
    }
  }
}

class StaffConcernsPage extends ConsumerWidget {
  const StaffConcernsPage({super.key, required this.role});
  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffConcernsProvider(role));
    final selectedStatus = ref.watch(_concernStatusFilterProvider(role));
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('concerns_support'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800)),
            Text(context.tr('staff_concern_subtitle'),
                style: const TextStyle(color: Color(0xFF94A3B8))),
            Wrap(
              spacing: 7,
              children: {
                'all': context.tr('all'),
                'submitted': context.tr('new_status'),
                'assigned': context.tr('assigned'),
                'in_progress': context.tr('in_progress'),
                'resolved': context.tr('resolved'),
              }
                  .entries
                  .map((entry) => FilterChip(
                        label: Text(entry.value),
                        selected: selectedStatus == entry.key,
                        onSelected: (_) => ref
                            .read(_concernStatusFilterProvider(role).notifier)
                            .state = entry.key,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(staffConcernsProvider(role)),
                    child: Text(context.tr('retry')),
                  ),
                ),
                data: (items) {
                  final filtered = selectedStatus == 'all'
                      ? items
                      : items
                          .where((item) => item['status'] == selectedStatus)
                          .toList();
                  return filtered.isEmpty
                      ? Center(child: Text(context.tr('no_routed_concerns')))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return Card(
                              color: const Color(0xFF1C2541),
                              child: ListTile(
                                title: Text(item['subject']?.toString() ??
                                    context.tr('concern')),
                                subtitle: Text(
                                  '${item['reference_no']} · ${_label(item['status'])} · ${_label(item['priority'])}',
                                ),
                                onTap: () => _review(
                                  context,
                                  ref,
                                  item['id'].toString(),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref, String id) async {
    final repository = ref.read(connectedOperationsRepositoryProvider);
    Map<String, dynamic> concern;
    try {
      concern = await repository.concern(id, role: role);
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return;
    }
    if (!context.mounted) return;
    final messages =
        (concern['messages'] as List? ?? const []).whereType<Map>().toList();
    var status = concern['status']?.toString() ?? 'submitted';
    var internal = false;
    final note = TextEditingController();
    final statuses = <String>{
      status,
      'under_review',
      'assigned',
      'in_progress',
      'needs_more_information',
      'resolved',
      'closed',
      'reopened',
    }.toList();
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              concern['reference_no']?.toString() ?? context.tr('concern')),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(concern['subject']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(concern['description']?.toString() ?? ''),
                  const Divider(),
                  ...messages.map((message) => ListTile(
                        dense: true,
                        leading: Icon(message['is_internal'] == true
                            ? Icons.lock_outline
                            : Icons.forum_outlined),
                        title: Text(message['message']?.toString() ?? ''),
                        subtitle: Text(message['is_internal'] == true
                            ? context.tr('internal_staff_note')
                            : context.tr('visible_to_tourist')),
                      )),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                        labelText: context.tr('workflow_status')),
                    items: statuses
                        .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(_translatedLabel(context, value))))
                        .toList(),
                    onChanged: (value) => setDialogState(() => status = value!),
                  ),
                  TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                        labelText: context.tr('reply_workflow_note')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: internal,
                    onChanged: (value) =>
                        setDialogState(() => internal = value),
                    title: Text(context.tr('internal_note')),
                    subtitle: Text(context.tr('never_shown_tourist')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.tr('cancel'))),
            if (role == 'lgu_staff')
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, 'escalate'),
                child: Text(context.tr('escalate_to_admin')),
              ),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, 'save'),
                child: Text(context.tr('save_update'))),
          ],
        ),
      ),
    );
    if (action == null) {
      note.dispose();
      return;
    }
    final noteText = note.text.trim();
    note.dispose();
    try {
      if (action == 'escalate') {
        await repository.updateConcern(id, role, {
          'escalate_to_admin': true,
          if (noteText.isNotEmpty) 'note': noteText,
          'is_internal': true,
        });
      } else {
        final statusChanged = status != concern['status']?.toString();
        if (statusChanged) {
          await repository.updateConcern(id, role, {
            'status': status,
            if (status == 'assigned') 'assign_to_self': true,
            if (noteText.isNotEmpty) 'note': noteText,
            'is_internal': internal,
          });
        } else if (noteText.isNotEmpty) {
          await repository.replyConcern(id, noteText,
              role: role, internal: internal);
        }
      }
      ref.invalidate(staffConcernsProvider(role));
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

final _concernStatusFilterProvider =
    StateProvider.autoDispose.family<String, String>((ref, role) => 'all');

const _relatedTypes = [
  'reservation',
  'ferry_schedule',
  'tourist_spot',
  'msme',
  'waste_report',
  'emergency_contact',
  'role_application',
];

String _relatedLabel(Map item, String type) {
  return switch (type) {
    'reservation' =>
      '${item['public_reference'] ?? 'Reservation'} · ${item['reservation_date'] ?? ''}',
    'ferry_schedule' =>
      '${item['route'] ?? 'Ferry schedule'} · ${item['departure_time'] ?? ''}',
    'tourist_spot' || 'msme' => item['name']?.toString() ?? 'Record',
    'waste_report' =>
      '${item['reference_no'] ?? 'Waste report'} · ${item['status'] ?? ''}',
    'emergency_contact' =>
      '${item['name'] ?? item['service_name'] ?? 'Emergency contact'}',
    'role_application' =>
      '${item['public_reference'] ?? item['reference_no'] ?? 'Role application'}',
    _ => item['name']?.toString() ?? 'Record',
  };
}

String _concernGuidance(
    BuildContext context, List<Map<String, dynamic>> categories, String? id) {
  final category = categories.where((item) => item['id']?.toString() == id);
  final redirect = category.firstOrNull?['redirect_feature']?.toString();
  return switch (redirect) {
    'reservation_messages' => context.tr('guidance_reservation'),
    'waste_report' => context.tr('guidance_waste'),
    'emergency_contacts' => context.tr('guidance_emergency'),
    _ => context.tr('guidance_related'),
  };
}

String _categoryLabel(BuildContext context, Map<String, dynamic> category) {
  final slug = category['slug']?.toString();
  if (slug != null) {
    final key = 'concern_category_$slug';
    final translated = context.tr(key);
    if (translated != key) return translated;
  }
  return category['name']?.toString() ?? context.tr('category');
}

String _translatedLabel(BuildContext context, dynamic value) {
  final raw = value?.toString() ?? '';
  final key = 'label_$raw';
  final translated = context.tr(key);
  return translated == key ? _label(raw) : translated;
}

void _showError(BuildContext context, Object error) {
  final message = switch (error) {
    NetworkException() => context.tr('network_action_required'),
    ValidationException() => context.tr('check_entered_information'),
    AuthException() => context.tr('not_authorized'),
    AppException() => context.tr('operation_failed'),
    _ => context.tr('operation_failed'),
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _label(dynamic value) => value
    .toString()
    .split('_')
    .map((part) =>
        part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
