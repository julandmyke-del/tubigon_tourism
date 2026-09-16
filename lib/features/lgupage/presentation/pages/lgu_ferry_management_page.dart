import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../ferry/repositories/ferry_repository.dart';
import '../../../admin/providers/admin_providers.dart';
import '../../providers/lgu_providers.dart';

const _weekdays = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

class LguFerryManagementPage extends ConsumerWidget {
  const LguFerryManagementPage({super.key, this.adminMode = false});

  final bool adminMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(lguFerrySchedulesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Ferry Schedule'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Ferry Schedule Management',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800)),
              OutlinedButton.icon(
                  onPressed: () => _manageCatalogs(context, ref),
                  icon: const Icon(Icons.alt_route_rounded),
                  label: const Text('Routes / Ports')),
              if (adminMode)
                OutlinedButton.icon(
                    onPressed: () => _manageOperators(context, ref),
                    icon: const Icon(Icons.directions_boat_filled_rounded),
                    label: const Text('Operators / Vessels')),
            ],
          ),
          const Text(
            'Publish date-specific or recurring services and operational advisories.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: schedules.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: OutlinedButton.icon(
                  onPressed: () => ref.invalidate(lguFerrySchedulesProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Unable to load schedules. Retry'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Text('No ferry schedules have been recorded.',
                          style: TextStyle(color: Color(0xFF94A3B8))))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(lguFerrySchedulesProvider.future),
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => _ScheduleCard(
                            item: items[index],
                            onEdit: () {
                              _edit(context, ref, existing: items[index]);
                            },
                            onArchive: () {
                              _archive(context, ref, items[index]);
                            }),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _archive(
      BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive ferry schedule?'),
        content: const Text(
            'It will be removed from the Tourist schedule after refresh.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive Schedule')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(lguRepositoryProvider)
          .archiveFerrySchedule(item['id'].toString());
      ref.invalidate(lguFerrySchedulesProvider);
      ref.invalidate(ferrySchedulesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ferry schedule archived.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to archive schedule: $error')));
      }
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _FerryFormDialog(
        existing: existing,
        onSaved: () {
          ref.invalidate(lguFerrySchedulesProvider);
          ref.invalidate(ferrySchedulesListProvider);
        },
      ),
    );
  }

  Future<void> _manageCatalogs(BuildContext context, WidgetRef ref) async {
    final catalogs = await ref.read(lguFerryCatalogsProvider.future);
    if (!context.mounted) return;
    final ports =
        (catalogs['ports'] as List? ?? const []).whereType<Map>().toList();
    final routes =
        (catalogs['routes'] as List? ?? const []).whereType<Map>().toList();
    final name = TextEditingController();
    final code = TextEditingController();
    final routeName = TextEditingController();
    String? origin;
    String? destination;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ferry Ports & Routes'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Schedules use this controlled operational catalog.'),
                  if (routes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${ports.length} ports · ${routes.length} routes'),
                  ],
                  if (ports.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Active ports',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    ...ports.map((port) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(port['name']?.toString() ?? 'Port'),
                          subtitle: Text(port['code']?.toString() ?? ''),
                          trailing: IconButton(
                            tooltip: 'Edit or deactivate port',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _editCatalogPort(context, ref, port),
                          ),
                        )),
                  ],
                  if (routes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Active routes',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    ...routes.map((route) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(route['name']?.toString() ?? 'Route'),
                          trailing: IconButton(
                            tooltip: 'Edit or deactivate route',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _editCatalogRoute(context, ref, route, ports),
                          ),
                        )),
                  ],
                  const Divider(height: 28),
                  TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'New Port Name'),
                  ),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Port Code'),
                  ),
                  const Divider(height: 28),
                  TextField(
                    controller: routeName,
                    decoration:
                        const InputDecoration(labelText: 'New Route Name'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: origin,
                          decoration:
                              const InputDecoration(labelText: 'Origin Port'),
                          items: ports
                              .map((port) => DropdownMenuItem(
                                    value: port['id'].toString(),
                                    child: Text(port['name'].toString()),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => origin = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: destination,
                          decoration: const InputDecoration(
                              labelText: 'Destination Port'),
                          items: ports
                              .map((port) => DropdownMenuItem(
                                    value: port['id'].toString(),
                                    child: Text(port['name'].toString()),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => destination = value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            OutlinedButton(
              onPressed: () async {
                if (name.text.trim().length < 2 || code.text.trim().isEmpty) {
                  return;
                }
                await ref.read(lguRepositoryProvider).createFerryPort({
                  'name': name.text.trim(),
                  'code': code.text.trim().toUpperCase(),
                  'municipality': 'Tubigon',
                  'province': 'Bohol',
                });
                ref.invalidate(lguFerryCatalogsProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Add Port'),
            ),
            FilledButton(
              onPressed: ports.length < 2 ||
                      origin == null ||
                      destination == null ||
                      origin == destination ||
                      routeName.text.trim().length < 2
                  ? null
                  : () async {
                      await ref.read(lguRepositoryProvider).createFerryRoute({
                        'name': routeName.text.trim(),
                        'origin_port_id': origin,
                        'destination_port_id': destination,
                      });
                      ref.invalidate(lguFerryCatalogsProvider);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('Add Route'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    code.dispose();
    routeName.dispose();
  }

  Future<void> _editCatalogPort(
      BuildContext context, WidgetRef ref, Map<dynamic, dynamic> port) async {
    final name = TextEditingController(text: port['name']?.toString());
    final code = TextEditingController(text: port['code']?.toString());
    var active = port['is_active'] != false && port['is_active'] != 0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Ferry Port'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Port name')),
            TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Port code')),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: active,
              onChanged: (value) => setState(() => active = value),
              title: const Text('Active'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().length < 2 || code.text.trim().isEmpty) {
                  return;
                }
                await ref.read(lguRepositoryProvider).updateFerryPort(
                  port['id'].toString(),
                  {
                    'name': name.text.trim(),
                    'code': code.text.trim().toUpperCase(),
                    'municipality': port['municipality'],
                    'province': port['province'],
                    'latitude': port['latitude'],
                    'longitude': port['longitude'],
                    'is_active': active,
                  },
                );
                ref.invalidate(lguFerryCatalogsProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save Port'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    code.dispose();
  }

  Future<void> _editCatalogRoute(BuildContext context, WidgetRef ref,
      Map<dynamic, dynamic> route, List<Map<dynamic, dynamic>> ports) async {
    final name = TextEditingController(text: route['name']?.toString());
    var origin = route['origin_port_id']?.toString();
    var destination = route['destination_port_id']?.toString();
    var active = route['is_active'] != false && route['is_active'] != 0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Ferry Route'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Route name')),
              DropdownButtonFormField<String>(
                initialValue:
                    ports.any((item) => item['id'].toString() == origin)
                        ? origin
                        : null,
                decoration: const InputDecoration(labelText: 'Origin port'),
                items: ports
                    .map((item) => DropdownMenuItem(
                        value: item['id'].toString(),
                        child: Text(item['name'].toString())))
                    .toList(),
                onChanged: (value) => setState(() => origin = value),
              ),
              DropdownButtonFormField<String>(
                initialValue:
                    ports.any((item) => item['id'].toString() == destination)
                        ? destination
                        : null,
                decoration:
                    const InputDecoration(labelText: 'Destination port'),
                items: ports
                    .map((item) => DropdownMenuItem(
                        value: item['id'].toString(),
                        child: Text(item['name'].toString())))
                    .toList(),
                onChanged: (value) => setState(() => destination = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: active,
                onChanged: (value) => setState(() => active = value),
                title: const Text('Active'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (origin == null ||
                    destination == null ||
                    origin == destination ||
                    name.text.trim().length < 2) {
                  return;
                }
                await ref.read(lguRepositoryProvider).updateFerryRoute(
                  route['id'].toString(),
                  {
                    'name': name.text.trim(),
                    'origin_port_id': origin,
                    'destination_port_id': destination,
                    'estimated_duration_minutes':
                        route['estimated_duration_minutes'],
                    'is_active': active,
                  },
                );
                ref.invalidate(lguFerryCatalogsProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save Route'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  Future<void> _manageOperators(BuildContext context, WidgetRef ref) async {
    List<Map<String, dynamic>> operators;
    try {
      operators = await ref.read(adminRepositoryProvider).getFerryOperators();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load ferry operators.')));
      }
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ferry Operators & Vessels'),
        content: SizedBox(
          width: 680,
          height: 480,
          child: operators.isEmpty
              ? const Center(child: Text('No ferry operators yet.'))
              : ListView(
                  children: operators.map((operator) {
                    final vessels = (operator['vessels'] as List? ?? const [])
                        .whereType<Map>()
                        .toList();
                    final active = operator['is_active'] != false &&
                        operator['is_active'] != 0;
                    return ExpansionTile(
                      title: Text(operator['name']?.toString() ?? 'Operator'),
                      subtitle: Text(active ? 'Active' : 'Inactive'),
                      trailing: IconButton(
                        tooltip: 'Edit operator',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _editOperator(context, ref, operator);
                          if (context.mounted) _manageOperators(context, ref);
                        },
                      ),
                      children: [
                        if (vessels.isEmpty)
                          const ListTile(title: Text('No vessels recorded.')),
                        ...vessels.map((vessel) => ListTile(
                              leading: const Icon(Icons.sailing_rounded),
                              title: Text(vessel['vessel_name']?.toString() ??
                                  'Vessel'),
                              subtitle: Text(vessel['is_active'] == false ||
                                      vessel['is_active'] == 0
                                  ? 'Inactive'
                                  : 'Active'),
                              trailing: IconButton(
                                tooltip: 'Edit vessel',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  Navigator.pop(dialogContext);
                                  await _editVessel(context, ref, operators,
                                      existing: vessel);
                                  if (context.mounted) {
                                    _manageOperators(context, ref);
                                  }
                                },
                              ),
                            )),
                      ],
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
          OutlinedButton.icon(
            onPressed: operators.isEmpty
                ? null
                : () async {
                    Navigator.pop(dialogContext);
                    await _editVessel(context, ref, operators);
                    if (context.mounted) _manageOperators(context, ref);
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Vessel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _editOperator(context, ref, null);
              if (context.mounted) _manageOperators(context, ref);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Operator'),
          ),
        ],
      ),
    );
  }

  Future<void> _editOperator(BuildContext context, WidgetRef ref,
      Map<String, dynamic>? existing) async {
    final name = TextEditingController(text: existing?['name']?.toString());
    final description =
        TextEditingController(text: existing?['description']?.toString());
    final contact =
        TextEditingController(text: existing?['contact_number']?.toString());
    final website =
        TextEditingController(text: existing?['website']?.toString());
    var active = existing == null ||
        (existing['is_active'] != false && existing['is_active'] != 0);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Operator' : 'Edit Operator'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        const InputDecoration(labelText: 'Operator name *')),
                TextField(
                    controller: description,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                TextField(
                    controller: contact,
                    decoration:
                        const InputDecoration(labelText: 'Contact number')),
                TextField(
                    controller: website,
                    decoration: const InputDecoration(labelText: 'Website')),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                  title: const Text('Active'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: name.text.trim().length < 2
                  ? null
                  : () async {
                      await ref
                          .read(adminRepositoryProvider)
                          .saveFerryOperator({
                        'name': name.text.trim(),
                        'description': description.text.trim().isEmpty
                            ? null
                            : description.text.trim(),
                        'contact_number': contact.text.trim().isEmpty
                            ? null
                            : contact.text.trim(),
                        'website': website.text.trim().isEmpty
                            ? null
                            : website.text.trim(),
                        'is_active': active,
                        if (existing?['updated_at'] != null)
                          'expected_updated_at': existing!['updated_at'],
                      }, id: existing?['id']?.toString());
                      _invalidateCatalogs(ref);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('Save Operator'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    contact.dispose();
    website.dispose();
  }

  Future<void> _editVessel(
      BuildContext context, WidgetRef ref, List<Map<String, dynamic>> operators,
      {Map<dynamic, dynamic>? existing}) async {
    final name =
        TextEditingController(text: existing?['vessel_name']?.toString());
    var operatorId = existing?['ferry_operator_id']?.toString() ??
        (operators.isEmpty ? null : operators.first['id']?.toString());
    var active = existing == null ||
        (existing['is_active'] != false && existing['is_active'] != 0);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Vessel' : 'Edit Vessel'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: operatorId,
                decoration: const InputDecoration(labelText: 'Operator *'),
                items: operators
                    .map((operator) => DropdownMenuItem(
                          value: operator['id'].toString(),
                          child: Text(operator['name'].toString()),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => operatorId = value),
              ),
              TextField(
                  controller: name,
                  onChanged: (_) => setState(() {}),
                  decoration:
                      const InputDecoration(labelText: 'Vessel name *')),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: active,
                onChanged: (value) => setState(() => active = value),
                title: const Text('Active'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: operatorId == null || name.text.trim().length < 2
                  ? null
                  : () async {
                      await ref.read(adminRepositoryProvider).saveFerryVessel({
                        'ferry_operator_id': operatorId,
                        'vessel_name': name.text.trim(),
                        'is_active': active,
                        if (existing?['updated_at'] != null)
                          'expected_updated_at': existing!['updated_at'],
                      }, id: existing?['id']?.toString());
                      _invalidateCatalogs(ref);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('Save Vessel'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  void _invalidateCatalogs(WidgetRef ref) {
    ref.invalidate(lguFerryCatalogsProvider);
    ref.invalidate(ferryOperatorsProvider);
    ref.invalidate(lguFerrySchedulesProvider);
    ref.invalidate(ferrySchedulesListProvider);
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard(
      {required this.item, required this.onEdit, required this.onArchive});
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final route = item['route']?.toString() ??
        '${item['origin'] ?? 'Origin'} → ${item['destination'] ?? 'Destination'}';
    final status = item['status']?.toString() ?? 'scheduled';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(children: [
        const CircleAvatar(
            child: Icon(Icons.directions_boat_rounded, size: 20)),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(route,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            Text(
              '${item['departure_time'] ?? 'Time unavailable'}'
              '${item['arrival_time'] == null ? '' : ' – ${item['arrival_time']}'} • ${item['operator'] ?? 'Operator unavailable'}',
              style: const TextStyle(color: Color(0xFFCBD5E1)),
            ),
            if (item['departure_date'] != null)
              Text('Service date: ${item['departure_date']}',
                  style: const TextStyle(color: Color(0xFF94A3B8))),
            if ((item['effective_from'] ?? item['valid_from']) != null)
              Text(
                  'Effective: ${item['effective_from'] ?? item['valid_from']}'
                  '${(item['effective_until'] ?? item['valid_until']) == null ? '' : ' to ${item['effective_until'] ?? item['valid_until']}'}',
                  style: const TextStyle(color: Color(0xFF94A3B8))),
            if (item['vessel_name'] != null)
              Text('Vessel: ${item['vessel_name']}',
                  style: const TextStyle(color: Color(0xFF94A3B8))),
            if (item['advisory']?.toString().isNotEmpty == true)
              Text('Advisory: ${item['advisory']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFFDE68A))),
          ]),
        ),
        Column(children: [
          Chip(label: Text(_label(status))),
          Text(
            item['is_active'] == false || item['is_active'] == 0
                ? 'Inactive'
                : (item['is_published'] == false || item['is_published'] == 0
                    ? 'Draft'
                    : 'Published'),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ]),
        IconButton(
            tooltip: 'Edit schedule',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined)),
        IconButton(
            tooltip: 'Archive schedule',
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined, color: Colors.redAccent)),
      ]),
    );
  }

  static String _label(String value) => value
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _FerryFormDialog extends ConsumerStatefulWidget {
  const _FerryFormDialog({required this.existing, required this.onSaved});
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  @override
  ConsumerState<_FerryFormDialog> createState() => _FerryFormDialogState();
}

class _FerryFormDialogState extends ConsumerState<_FerryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _origin;
  late final TextEditingController _destination;
  late final TextEditingController _operator;
  late final TextEditingController _vessel;
  late final TextEditingController _fare;
  late final TextEditingController _advisory;
  late final TextEditingController _contact;
  late final TextEditingController _reference;
  late final TextEditingController _sourceReference;
  late String _departure;
  String? _arrival;
  DateTime? _date;
  DateTime? _effectiveFrom;
  DateTime? _effectiveUntil;
  late String _status;
  String? _routeId;
  String? _operatorId;
  String? _vesselId;
  late Set<String> _days;
  late bool _published;
  late bool _active;
  late bool _arrivalNextDay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.existing ?? const <String, dynamic>{};
    final route = value['route']?.toString().replaceAll('â†’', '→').split('→');
    _origin = TextEditingController(
        text: value['origin']?.toString() ??
            (route != null && route.isNotEmpty ? route.first.trim() : ''));
    _destination = TextEditingController(
        text: value['destination']?.toString() ??
            (route != null && route.length > 1 ? route.last.trim() : ''));
    _operator = TextEditingController(text: value['operator']?.toString());
    _vessel = TextEditingController(text: value['vessel_name']?.toString());
    _fare = TextEditingController(text: value['fare']?.toString());
    _advisory = TextEditingController(text: value['advisory']?.toString());
    _contact =
        TextEditingController(text: value['contact_information']?.toString());
    _reference =
        TextEditingController(text: value['reference_url']?.toString());
    _sourceReference =
        TextEditingController(text: value['source_reference']?.toString());
    _departure = value['departure_time']?.toString() ?? '08:00';
    _arrival = value['arrival_time']?.toString();
    _date = DateTime.tryParse(value['departure_date']?.toString() ?? '');
    _effectiveFrom = DateTime.tryParse(
        (value['effective_from'] ?? value['valid_from'])?.toString() ?? '');
    _effectiveUntil = DateTime.tryParse(
        (value['effective_until'] ?? value['valid_until'])?.toString() ?? '');
    _status = value['status']?.toString() ?? 'scheduled';
    _routeId = value['ferry_route_id']?.toString();
    _operatorId =
        (value['operator_id'] ?? value['ferry_operator_id'])?.toString();
    _vesselId = (value['vessel_id'] ?? value['ferry_vessel_id'])?.toString();
    _published = value.isEmpty ||
        value['is_published'] == true ||
        value['is_published'] == 1;
    _active =
        value.isEmpty || value['is_active'] == true || value['is_active'] == 1;
    _arrivalNextDay =
        value['arrival_next_day'] == true || value['arrival_next_day'] == 1;
    final days = value['days_of_week'];
    _days = days is List
        ? days.map((item) => item.toString().toLowerCase()).toSet()
        : <String>{};
  }

  @override
  void dispose() {
    for (final controller in [
      _origin,
      _destination,
      _operator,
      _vessel,
      _fare,
      _advisory,
      _contact,
      _reference,
      _sourceReference,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null
            ? 'Add Ferry Schedule'
            : 'Edit Ferry Schedule'),
        content: SizedBox(
          width: 620,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ref.watch(lguFerryCatalogsProvider).when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text(
                          'Route catalog unavailable. Existing route names are shown as a compatibility fallback.'),
                      data: (catalogs) {
                        final routes = (catalogs['routes'] as List? ?? const [])
                            .whereType<Map>()
                            .toList();
                        if (routes.isEmpty) {
                          return const Text(
                              'No structured ferry route exists yet. Add ports/routes through the LGU API before publishing new schedules.');
                        }
                        final operators =
                            (catalogs['operators'] as List? ?? const [])
                                .whereType<Map>()
                                .toList();
                        Map<dynamic, dynamic>? selectedOperator;
                        for (final operator in operators) {
                          if (operator['id']?.toString() == _operatorId) {
                            selectedOperator = operator;
                            break;
                          }
                        }
                        final vessels =
                            (selectedOperator?['vessels'] as List? ?? const [])
                                .whereType<Map>()
                                .toList();
                        return Column(children: [
                          DropdownButtonFormField<String>(
                            initialValue: routes
                                    .any((r) => r['id']?.toString() == _routeId)
                                ? _routeId
                                : null,
                            decoration: const InputDecoration(
                                labelText: 'Ferry Route *'),
                            items: routes
                                .map((r) => DropdownMenuItem(
                                    value: r['id'].toString(),
                                    child:
                                        Text(r['name']?.toString() ?? 'Route')))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _routeId = value),
                            validator: (value) => value == null
                                ? 'Select a structured route.'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: operators.any((operator) =>
                                    operator['id']?.toString() == _operatorId)
                                ? _operatorId
                                : null,
                            decoration:
                                const InputDecoration(labelText: 'Operator *'),
                            items: operators
                                .map((operator) => DropdownMenuItem(
                                      value: operator['id'].toString(),
                                      child: Text(operator['name'].toString()),
                                    ))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) => setState(() {
                                      _operatorId = value;
                                      _vesselId = null;
                                      final selected = operators.firstWhere(
                                          (item) =>
                                              item['id']?.toString() == value);
                                      _operator.text =
                                          selected['name']?.toString() ?? '';
                                      _vessel.clear();
                                    }),
                            validator: (value) => value == null
                                ? 'Select a ferry operator.'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String?>(
                            key: ValueKey(_operatorId),
                            initialValue: vessels.any((vessel) =>
                                    vessel['id']?.toString() == _vesselId)
                                ? _vesselId
                                : null,
                            decoration: const InputDecoration(
                                labelText: 'Vessel (optional)'),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('No vessel')),
                              ...vessels.map((vessel) =>
                                  DropdownMenuItem<String?>(
                                    value: vessel['id'].toString(),
                                    child:
                                        Text(vessel['vessel_name'].toString()),
                                  )),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => setState(() {
                                      _vesselId = value;
                                      _vessel.text = value == null
                                          ? ''
                                          : vessels
                                              .firstWhere((item) =>
                                                  item['id']?.toString() ==
                                                  value)['vessel_name']
                                              .toString();
                                    }),
                          ),
                        ]);
                      },
                    ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pickTime(true),
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text('Departure: $_departure'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : () => _pickTime(false),
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text('Arrival: ${_arrival ?? 'Unknown'}'),
                          ),
                        ),
                        if (_arrival != null)
                          IconButton(
                            tooltip: 'Clear arrival time',
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _arrival = null;
                                      _arrivalNextDay = false;
                                    }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                  ),
                ]),
                if (_arrival != null)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _arrivalNextDay,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _arrivalNextDay = value),
                    title: const Text('Arrival is on the next day'),
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _pickDate,
                            icon: const Icon(Icons.event_rounded),
                            label: Text(_date == null
                                ? 'No specific date'
                                : DateFormat.yMMMd().format(_date!)),
                          ),
                        ),
                        if (_date != null)
                          IconButton(
                            tooltip: 'Clear schedule date',
                            onPressed: _saving
                                ? null
                                : () => setState(() => _date = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _fare,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'))
                      ],
                      decoration:
                          const InputDecoration(labelText: 'Fare (PHP)'),
                      validator: (value) =>
                          value!.isNotEmpty && double.tryParse(value) == null
                              ? 'Enter a valid amount.'
                              : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickEffectiveDate(start: true),
                      icon: const Icon(Icons.today_rounded),
                      label: Text(_effectiveFrom == null
                          ? 'Effective from'
                          : DateFormat.yMMMd().format(_effectiveFrom!)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickEffectiveDate(start: false),
                      icon: const Icon(Icons.event_available_rounded),
                      label: Text(_effectiveUntil == null
                          ? 'No end date'
                          : DateFormat.yMMMd().format(_effectiveUntil!)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status *'),
                  items: const [
                    'scheduled',
                    'boarding',
                    'delayed',
                    'departed',
                    'arrived',
                    'cancelled',
                    'suspended',
                  ]
                      .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(_ScheduleCard._label(value))))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _status = value!),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recurring operating days (optional)'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: _weekdays
                        .map((day) => FilterChip(
                              label: Text(day.substring(0, 3).toUpperCase()),
                              selected: _days.contains(day),
                              onSelected: _saving
                                  ? null
                                  : (selected) => setState(() => selected
                                      ? _days.add(day)
                                      : _days.remove(day)),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 10),
                _field(_advisory, 'Advisory / remarks', maxLines: 3),
                const SizedBox(height: 10),
                _field(_contact, 'Contact / reference information'),
                const SizedBox(height: 10),
                _field(_sourceReference, 'Source / reference note',
                    maxLines: 2),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reference,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                      labelText: 'Reference URL (optional)'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final uri = Uri.tryParse(value.trim());
                    return uri != null && {'http', 'https'}.contains(uri.scheme)
                        ? null
                        : 'Enter a valid http/https URL.';
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _published,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _published = value),
                  title: Text(_published ? 'Published to travelers' : 'Draft'),
                  subtitle: const Text(
                    'Draft schedules remain available to LGU and Admin staff only.',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _active = value),
                  title:
                      Text(_active ? 'Active schedule' : 'Inactive schedule'),
                  subtitle: const Text(
                      'Inactive schedules are hidden from travelers but remain editable.'),
                ),
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
                : Text(_published ? 'Publish Ferry Schedule' : 'Save Draft'),
          ),
        ],
      );

  Widget _field(TextEditingController controller, String label,
          {int maxLines = 1}) =>
      TextFormField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label));

  Future<void> _pickTime(bool departure) async {
    final raw = departure ? _departure : _arrival;
    final parts = raw?.split(':');
    final initial = parts?.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts![0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 8, minute: 0);
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value == null || !mounted) return;
    final formatted =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    setState(() => departure ? _departure = formatted : _arrival = formatted);
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today.add(const Duration(days: 730)),
      initialDate: _date ?? today,
    );
    if (value != null && mounted) {
      setState(() {
        _date = value;
        _effectiveFrom = null;
        _effectiveUntil = null;
      });
    }
  }

  Future<void> _pickEffectiveDate({required bool start}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = start ? _effectiveFrom : _effectiveUntil;
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today.add(const Duration(days: 3650)),
      initialDate: current ?? _effectiveFrom ?? today,
    );
    if (value == null || !mounted) return;
    setState(() {
      _date = null;
      if (start) {
        _effectiveFrom = value;
        if (_effectiveUntil != null && _effectiveUntil!.isBefore(value)) {
          _effectiveUntil = null;
        }
      } else {
        _effectiveUntil = value;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_effectiveUntil != null && _effectiveFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose an effective start date first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(lguRepositoryProvider).saveFerrySchedule({
        if (_routeId != null) 'ferry_route_id': _routeId,
        if (_routeId == null) 'origin': _origin.text.trim(),
        if (_routeId == null) 'destination': _destination.text.trim(),
        'ferry_operator_id': _operatorId,
        'operator': _operator.text.trim(),
        'ferry_vessel_id': _vesselId,
        'vessel_name': _vessel.text.trim().isEmpty ? null : _vessel.text.trim(),
        'departure_date': _date?.toIso8601String().split('T').first,
        'valid_from': _effectiveFrom?.toIso8601String().split('T').first,
        'valid_until': _effectiveUntil?.toIso8601String().split('T').first,
        'departure_time': _departure,
        'arrival_time': _arrival,
        'arrival_next_day': _arrivalNextDay,
        'fare':
            _fare.text.trim().isEmpty ? null : double.parse(_fare.text.trim()),
        'status': _status,
        'days_of_week': _days.toList()..sort(),
        'advisory':
            _advisory.text.trim().isEmpty ? null : _advisory.text.trim(),
        'contact_information':
            _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        'reference_url':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        'source_reference': _sourceReference.text.trim().isEmpty
            ? null
            : _sourceReference.text.trim(),
        'is_active': _active,
        'is_published': _published,
        if (widget.existing?['updated_at'] != null)
          'expected_updated_at': widget.existing!['updated_at'],
      }, id: widget.existing?['id']?.toString());
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to save schedule: $error')));
        setState(() => _saving = false);
      }
    }
  }
}
