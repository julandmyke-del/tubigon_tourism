import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/auth_provider.dart';
import '../../notifications/repositories/notification_repository.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../data/connected_operations_repository.dart';

class DynamicBookingPage extends ConsumerStatefulWidget {
  const DynamicBookingPage({super.key, required this.spotId});
  final String spotId;
  @override
  ConsumerState<DynamicBookingPage> createState() => _DynamicBookingPageState();
}

class _DynamicBookingPageState extends ConsumerState<DynamicBookingPage> {
  DateTime date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? time;
  final selected = <String>{};
  final quantities = <String, int>{};
  final values = <String, TextEditingController>{};
  final notes = TextEditingController();
  Set<String> _pendingOfferingIds = const {};
  Set<String> _pendingControllerKeys = const {};
  bool _offeringReconciliationScheduled = false;
  bool saving = false;
  @override
  void dispose() {
    for (final c in values.values) {
      c.dispose();
    }
    notes.dispose();
    super.dispose();
  }

  String get dateValue =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String? get timeValue => time == null
      ? null
      : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn) {
      return const Scaffold(
          body: Center(child: Text('Sign in to make a reservation.')));
    }
    final state = ref.watch(publicOfferingsProvider(widget.spotId));
    return Scaffold(
        backgroundColor: const Color(0xFF080F1A),
        appBar: AppBar(title: const Text('Choose Booking Options')),
        body: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _messageState(
                'Booking options could not be loaded.',
                () => ref.invalidate(publicOfferingsProvider(widget.spotId))),
            data: (payload) {
              final items = (payload['data'] as List? ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              final meta = payload['meta'] is Map
                  ? Map<String, dynamic>.from(payload['meta'] as Map)
                  : <String, dynamic>{};
              if (items.isEmpty) {
                return _messageState(
                    'No booking options are currently available.',
                    () =>
                        ref.invalidate(publicOfferingsProvider(widget.spotId)));
              }
              final enabled = meta['booking_enabled'] == true;
              _scheduleOfferingReconciliation(items);
              return ListView(padding: const EdgeInsets.all(20), children: [
                if (meta['cover_url']?.toString().isNotEmpty == true)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      meta['cover_url'].toString(),
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                if (meta['destination_name'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      meta['destination_name'].toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                if (payload['offline'] == true)
                  const _Notice(
                      'Offline copy — connect to submit a reservation.',
                      Icons.cloud_off_rounded),
                if (!enabled)
                  _Notice(
                      'Booking is currently unavailable. ${meta['unavailable_reason'] ?? ''}',
                      Icons.event_busy_rounded),
                const Text('Available offerings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...items.map((item) => _offering(item)),
                const SizedBox(height: 16),
                ListTile(
                    tileColor: const Color(0xFF111C2F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.calendar_month,
                        color: Color(0xFFF59E0B)),
                    title: Text(dateValue),
                    onTap: () async {
                      final p = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)));
                      if (p != null) setState(() => date = p);
                    }),
                const SizedBox(height: 10),
                ListTile(
                    tileColor: const Color(0xFF111C2F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading:
                        const Icon(Icons.schedule, color: Color(0xFFF59E0B)),
                    title: Text(timeValue ?? 'Select time if required'),
                    trailing: time == null
                        ? null
                        : IconButton(
                            onPressed: () => setState(() => time = null),
                            icon: const Icon(Icons.close)),
                    onTap: () async {
                      final p = await showTimePicker(
                          context: context,
                          initialTime:
                              time ?? const TimeOfDay(hour: 9, minute: 0));
                      if (p != null) setState(() => time = p);
                    }),
                const SizedBox(height: 10),
                TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Special requests (optional)')),
                const SizedBox(height: 16),
                Text('Estimated total: ₱${_total(items).toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const Text(
                    'Laravel recalculates the final total from current prices and availability.',
                    style: TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: !enabled || saving || selected.isEmpty
                        ? null
                        : () => _submit(items),
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lock_outline),
                    label: const Text('Review and Submit')),
              ]);
            }));
  }

  Widget _offering(Map<String, dynamic> item) {
    final id = item['id'].toString();
    final active = selected.contains(id);
    final fields = (item['fields'] as List? ?? const []).whereType<Map>();
    return Card(
        key: ValueKey('booking-offering-$id'),
        color: const Color(0xFF111C2F),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (v) => setState(() {
                        v == true ? selected.add(id) : selected.remove(id);
                        quantities[id] ??= 1;
                      }),
                  title: Text(item['display_name']?.toString() ?? 'Offering',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${_label(item['type'])} · ₱${item['price']} · ${_label(item['pricing_mode'])}')),
              if (active) ...[
                Row(children: [
                  const Text('Quantity'),
                  IconButton(
                      onPressed: (quantities[id] ?? 1) >
                              ((item['min_quantity'] as num?)?.toInt() ?? 1)
                          ? () => setState(
                              () => quantities[id] = (quantities[id] ?? 1) - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('${quantities[id] ?? 1}'),
                  IconButton(
                      onPressed: _canIncrease(item, quantities[id] ?? 1)
                          ? () => setState(
                              () => quantities[id] = (quantities[id] ?? 1) + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline))
                ]),
                ...fields.map((f) {
                  final field = Map<String, dynamic>.from(f);
                  final fieldKey = '$id:${field['field_key']}';
                  return KeyedSubtree(
                    key: ValueKey('booking-field-$fieldKey'),
                    child: _dynamicField(id, field),
                  );
                }),
              ]
            ])));
  }

  void _scheduleOfferingReconciliation(List<Map<String, dynamic>> items) {
    _pendingOfferingIds = items.map((item) => item['id'].toString()).toSet();
    _pendingControllerKeys = {
      for (final item in items)
        for (final raw
            in (item['fields'] as List? ?? const []).whereType<Map>())
          '${item['id']}:${raw['field_key']}',
    };
    if (_offeringReconciliationScheduled) return;
    _offeringReconciliationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _offeringReconciliationScheduled = false;
      if (!mounted) return;
      selected.removeWhere((id) => !_pendingOfferingIds.contains(id));
      quantities.removeWhere((id, _) => !_pendingOfferingIds.contains(id));
      final staleKeys = values.keys
          .where((key) => !_pendingControllerKeys.contains(key))
          .toList(growable: false);
      for (final key in staleKeys) {
        values.remove(key)?.dispose();
      }
    });
  }

  Widget _dynamicField(String offering, Map<String, dynamic> field) {
    final key = '$offering:${field['field_key']}';
    final controller = values.putIfAbsent(key, () => TextEditingController());
    final type = field['field_type']?.toString();
    final options = (field['options_json'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    final label =
        '${field['label']}${field['is_required'] == true ? ' *' : ''}';

    if (type == 'date') {
      if (controller.text.isEmpty) controller.text = dateValue;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_month),
        title: Text(label),
        subtitle: Text(controller.text),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(controller.text) ?? date,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 730)),
          );
          if (picked != null) {
            setState(() {
              date = picked;
              controller.text = dateValue;
            });
          }
        },
      );
    }
    if (type == 'time') {
      if (controller.text.isEmpty && timeValue != null) {
        controller.text = timeValue!;
      }
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(label),
        subtitle:
            Text(controller.text.isEmpty ? 'Select time' : controller.text),
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
          );
          if (picked != null) {
            setState(() {
              time = picked;
              controller.text = timeValue!;
            });
          }
        },
      );
    }
    if (type == 'date_range') {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.date_range),
        title: Text(label),
        subtitle: Text(
            controller.text.isEmpty ? 'Select date range' : controller.text),
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 730)),
          );
          if (picked != null) {
            setState(() {
              date = picked.start;
              controller.text =
                  '${_date(picked.start)} to ${_date(picked.end)}';
            });
          }
        },
      );
    }
    if (type == 'boolean') {
      if (controller.text.isEmpty) controller.text = 'false';
      return SwitchListTile(
        value: controller.text == 'true',
        onChanged: (value) =>
            setState(() => controller.text = value.toString()),
        title: Text(label),
      );
    }
    if (type == 'select' && options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        items: options
            .map((option) =>
                DropdownMenuItem(value: option, child: Text(option)))
            .toList(),
        onChanged: (value) => controller.text = value ?? '',
        decoration: InputDecoration(labelText: label),
      );
    }
    if (type == 'multi_select' && options.isNotEmpty) {
      final chosen = controller.text.isEmpty
          ? <String>{}
          : (jsonDecode(controller.text) as List)
              .map((value) => value.toString())
              .toSet();
      return InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Wrap(
          spacing: 6,
          children: options
              .map((option) => FilterChip(
                    label: Text(option),
                    selected: chosen.contains(option),
                    onSelected: (selected) => setState(() {
                      selected ? chosen.add(option) : chosen.remove(option);
                      controller.text =
                          chosen.isEmpty ? '' : jsonEncode(chosen.toList());
                    }),
                  ))
              .toList(),
        ),
      );
    }
    if (['quantity', 'guest_count', 'adult_count', 'child_count']
        .contains(type)) {
      final minimum = (field['min_value'] as num?)?.toInt() ?? 0;
      final maximum = (field['max_value'] as num?)?.toInt();
      final current = int.tryParse(controller.text) ?? minimum;
      if (controller.text.isEmpty) controller.text = '$current';
      return Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: current > minimum
                ? () => setState(() => controller.text = '${current - 1}')
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$current'),
          IconButton(
            onPressed: maximum == null || current < maximum
                ? () => setState(() => controller.text = '${current + 1}')
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      );
    }
    return TextField(
      controller: controller,
      maxLines: type == 'notes' ? 3 : 1,
      decoration: InputDecoration(labelText: label),
    );
  }

  bool _canIncrease(Map<String, dynamic> item, int current) {
    final maximum = (item['max_quantity'] as num?)?.toInt();
    final stock = (item['quantity_available'] as num?)?.toInt();
    final limit = [maximum, stock].whereType<int>().fold<int?>(
        null, (value, next) => value == null || next < value ? next : value);
    return limit == null || current < limit;
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  double _total(List<Map<String, dynamic>> items) {
    var total = 0.0;
    for (final i in items.where((e) => selected.contains(e['id'].toString()))) {
      final id = i['id'].toString();
      final price = (i['price'] as num?)?.toDouble() ?? 0;
      var multiplier = quantities[id] ?? 1;
      final mode = i['pricing_mode'];
      if (mode == 'per_person' || mode == 'per_adult' || mode == 'per_child') {
        final key = mode == 'per_person'
            ? 'guest_count'
            : mode == 'per_adult'
                ? 'adult_count'
                : 'child_count';
        multiplier = int.tryParse(values['$id:$key']?.text ?? '') ?? multiplier;
      }
      total += price * multiplier;
    }
    return total;
  }

  Future<void> _submit(List<Map<String, dynamic>> items) async {
    for (final item
        in items.where((e) => selected.contains(e['id'].toString()))) {
      for (final raw
          in (item['fields'] as List? ?? const []).whereType<Map>()) {
        final f = Map<String, dynamic>.from(raw);
        if (f['is_required'] == true &&
            (values['${item['id']}:${f['field_key']}']?.text.trim().isEmpty ??
                true)) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${f['label']} is required.')));
          return;
        }
      }
    }
    setState(() => saving = true);
    try {
      final lines =
          items.where((e) => selected.contains(e['id'].toString())).map((item) {
        final id = item['id'].toString();
        final details = <String, dynamic>{};
        for (final raw
            in (item['fields'] as List? ?? const []).whereType<Map>()) {
          final f = Map<String, dynamic>.from(raw);
          final v = values['$id:${f['field_key']}']?.text.trim();
          if (v?.isNotEmpty == true) {
            details[f['field_key'].toString()] =
                f['field_type'] == 'multi_select' ? jsonDecode(v!) : v;
          }
        }
        return {
          'offering_id': id,
          'quantity': quantities[id] ?? 1,
          'booking_details': details
        };
      }).toList();
      final saved = await ref
          .read(connectedOperationsRepositoryProvider)
          .createOfferingReservation({
        'tourist_spot_id': widget.spotId,
        'reservation_date': dateValue,
        if (timeValue != null) 'start_time': timeValue,
        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
        'items': lines
      });
      ref.invalidate(reservationsListProvider);
      ref.invalidate(touristNotificationsProvider);
      if (mounted) context.go('/reservations/${saved['id']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _messageState(String text, VoidCallback retry) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'))
      ]));
  String _label(dynamic v) => v
      .toString()
      .split('_')
      .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, this.icon);
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF33250D),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFF59E0B)),
        const SizedBox(width: 10),
        Expanded(child: Text(text))
      ]));
}
