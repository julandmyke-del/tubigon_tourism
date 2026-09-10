import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../tourism_partner/providers/tourism_partner_providers.dart';
import '../data/connected_operations_repository.dart';

class PartnerDestinationOperationsPage extends ConsumerWidget {
  const PartnerDestinationOperationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignment = ref.watch(currentPartnerAssignmentProvider);
    return assignment.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          const Center(child: Text('Unable to load the assigned destination.')),
      data: (value) {
        final destination = value?['destination'];
        final id = destination is Map ? destination['id']?.toString() : null;
        if (id == null) {
          return const Center(
              child: Text('No Tourist Spot is assigned to this Partner.'));
        }
        final name = destination is Map
            ? destination['name']?.toString() ?? 'My Destination'
            : 'My Destination';
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color(0xFF080F1A),
            appBar: AppBar(
              title: Text(name),
              bottom: const TabBar(
                tabs: [
                  Tab(
                      icon: Icon(Icons.event_available),
                      text: 'Booking Offerings'),
                  Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
                ],
              ),
            ),
            body: TabBarView(
              children: [_Offerings(spotId: id), _Gallery(spotId: id)],
            ),
          ),
        );
      },
    );
  }
}

class _Offerings extends ConsumerWidget {
  const _Offerings({required this.spotId});
  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(partnerOfferingsProvider(spotId));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Offering'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(partnerOfferingsProvider(spotId)),
            child: const Text('Retry'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No offerings yet. Add the first booking option.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    color: const Color(0xFF111C2F),
                    child: ListTile(
                      title:
                          Text(item['display_name']?.toString() ?? 'Offering'),
                      subtitle: Text(
                        '${_label(item['type'])} · ₱${item['price']} · ${_label(item['pricing_mode'])}\n'
                        '${item['quantity_available'] ?? 'Unlimited'} available · ${(item['fields'] as List? ?? const []).length} form fields',
                      ),
                      isThreeLine: true,
                      leading: Icon(
                        item['is_active'] == true
                            ? Icons.check_circle
                            : Icons.pause_circle,
                        color: item['is_active'] == true
                            ? Colors.green
                            : Colors.grey,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _edit(context, ref, item: item);
                          } else {
                            await ref
                                .read(connectedOperationsRepositoryProvider)
                                .disableOffering(spotId, item['id'].toString());
                            _refresh(ref);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                              value: 'disable', child: Text('Disable')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(partnerOfferingsProvider(spotId));
    ref.invalidate(publicOfferingsProvider(spotId));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? item}) async {
    final name = TextEditingController(text: item?['display_name']?.toString());
    final description =
        TextEditingController(text: item?['description']?.toString());
    final price = TextEditingController(text: item?['price']?.toString());
    final capacity =
        TextEditingController(text: item?['capacity_per_unit']?.toString());
    final stock =
        TextEditingController(text: item?['quantity_available']?.toString());
    final minimum =
        TextEditingController(text: item?['min_quantity']?.toString() ?? '1');
    final maximum =
        TextEditingController(text: item?['max_quantity']?.toString());
    final advance =
        TextEditingController(text: item?['max_advance_days']?.toString());
    final lead =
        TextEditingController(text: item?['lead_time_minutes']?.toString());
    final cancellation =
        TextEditingController(text: item?['cancellation_note']?.toString());
    final operating =
        TextEditingController(text: item?['operating_note']?.toString());
    var type = item?['type']?.toString() ?? 'cottage';
    var pricing = item?['pricing_mode']?.toString() ?? 'per_cottage';
    var active = item?['is_active'] != false;
    var addOn = item?['is_add_on'] == true;
    final selectedDays = (item?['available_days'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final timeSlots = (item?['time_slots'] as List? ?? const [])
        .whereType<Map>()
        .map((slot) => slot['start']?.toString())
        .whereType<String>()
        .toSet();
    final blackoutDates = (item?['blackout_dates'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final selectedFields = (item?['fields'] as List? ?? const [])
        .whereType<Map>()
        .map((field) => field['field_key']?.toString())
        .whereType<String>()
        .toSet();
    final requiredFields = (item?['fields'] as List? ?? const [])
        .whereType<Map>()
        .where((field) => field['is_required'] == true)
        .map((field) => field['field_key']?.toString())
        .whereType<String>()
        .toSet();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add Offering' : 'Edit Offering'),
          content: SizedBox(
            width: 660,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration:
                        const InputDecoration(labelText: 'Offering Type'),
                    items: _offeringTypes
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text(_label(value))))
                        .toList(),
                    onChanged: (value) => setDialogState(() => type = value!),
                  ),
                  TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Display Name'),
                  ),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: pricing,
                    decoration:
                        const InputDecoration(labelText: 'Pricing Method'),
                    items: _pricingModes
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text(_label(value))))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => pricing = value!),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child:
                            _numberField(price, 'Price (PHP)', decimal: true),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _numberField(stock, 'Units available')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _numberField(capacity, 'Guests per unit')),
                    ],
                  ),
                  _numberField(lead, 'Minimum lead time (minutes)'),
                  Row(
                    children: [
                      Expanded(
                          child: _numberField(minimum, 'Minimum quantity')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _numberField(maximum, 'Maximum quantity')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _numberField(advance, 'Advance booking days')),
                    ],
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('Available days'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      children: _weekdays
                          .map((day) => FilterChip(
                                label: Text(day.substring(0, 3).toUpperCase()),
                                selected: selectedDays.contains(day),
                                onSelected: (selected) => setDialogState(() {
                                  selected
                                      ? selectedDays.add(day)
                                      : selectedDays.remove(day);
                                }),
                              ))
                          .toList(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        ...timeSlots.map((slot) => InputChip(
                              label: Text(slot),
                              onDeleted: () =>
                                  setDialogState(() => timeSlots.remove(slot)),
                            )),
                        ActionChip(
                          avatar: const Icon(Icons.add_alarm, size: 18),
                          label: const Text('Add time slot'),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (picked != null) {
                              final value =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                              setDialogState(() => timeSlots.add(value));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        ...blackoutDates.map((date) => InputChip(
                              label: Text(date),
                              onDeleted: () => setDialogState(
                                  () => blackoutDates.remove(date)),
                            )),
                        ActionChip(
                          avatar: const Icon(Icons.event_busy, size: 18),
                          label: const Text('Add blackout date'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) {
                              final value =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                              setDialogState(() => blackoutDates.add(value));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('Reservation form fields'),
                    ),
                  ),
                  ..._configurableFields.map((field) {
                    final key = field.$1;
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selectedFields.contains(key),
                      title: Text(field.$2),
                      subtitle: selectedFields.contains(key)
                          ? CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: requiredFields.contains(key),
                              title: const Text('Required'),
                              onChanged: (required) => setDialogState(() {
                                required == true
                                    ? requiredFields.add(key)
                                    : requiredFields.remove(key);
                              }),
                            )
                          : null,
                      onChanged: (selected) => setDialogState(() {
                        if (selected == true) {
                          selectedFields.add(key);
                        } else {
                          selectedFields.remove(key);
                          requiredFields.remove(key);
                        }
                      }),
                    );
                  }),
                  TextField(
                    controller: cancellation,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Cancellation policy'),
                  ),
                  TextField(
                    controller: operating,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Operating notes'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: addOn,
                    onChanged: (value) => setDialogState(() => addOn = value),
                    title: const Text('Add-on service'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                    title: const Text('Active and bookable'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    if (name.text.trim().length < 2 || double.tryParse(price.text) == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter a name and a valid non-negative price.')));
      }
      return;
    }
    final fields = <Map<String, dynamic>>[];
    for (final field in _configurableFields) {
      if (!selectedFields.contains(field.$1)) continue;
      fields.add({
        'field_key': field.$1,
        'label': field.$2,
        'field_type': field.$3,
        if (field.$4 != null) 'options_json': field.$4,
        'is_required': requiredFields.contains(field.$1),
        'sort_order': fields.length,
      });
    }
    await ref.read(connectedOperationsRepositoryProvider).saveOffering(
          spotId,
          {
            'type': type,
            'display_name': name.text.trim(),
            'description': _nullable(description.text),
            'price': double.parse(price.text),
            'pricing_mode': pricing,
            'capacity_per_unit': _integer(capacity.text),
            'quantity_available': _integer(stock.text),
            'min_quantity': _integer(minimum.text) ?? 1,
            'max_quantity': _integer(maximum.text),
            'max_advance_days': _integer(advance.text),
            'lead_time_minutes': _integer(lead.text),
            'available_days': selectedDays.toList(),
            'time_slots': timeSlots.map((start) => {'start': start}).toList(),
            'blackout_dates': blackoutDates.toList(),
            'cancellation_note': _nullable(cancellation.text),
            'operating_note': _nullable(operating.text),
            'is_add_on': addOn,
            'is_active': active,
            'fields': fields,
          },
          id: item?['id']?.toString(),
        );
    _refresh(ref);
  }

  static Widget _numberField(TextEditingController controller, String label,
      {bool decimal = false}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _Gallery extends ConsumerWidget {
  const _Gallery({required this.spotId});
  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(partnerGalleryProvider(spotId));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upload(context, ref),
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Add Photo'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(partnerGalleryProvider(spotId)),
            child: const Text('Retry'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No gallery photos yet.'))
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: items.length,
                onReorderItem: (oldIndex, newIndex) async {
                  final reordered = [...items];
                  final moved = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, moved);
                  await ref
                      .read(connectedOperationsRepositoryProvider)
                      .reorderGallery(
                        spotId,
                        reordered.map((item) => item['id'].toString()).toList(),
                      );
                  _refresh(ref);
                },
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    key: ValueKey(item['id']),
                    color: const Color(0xFF111C2F),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item['url'].toString(),
                          width: 84,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox(
                                  width: 84, child: Icon(Icons.broken_image)),
                        ),
                      ),
                      title: Text(item['caption']?.toString().isNotEmpty == true
                          ? item['caption'].toString()
                          : 'Destination photo'),
                      subtitle: Text(
                        '${_label(item['media_category'])}${item['is_active'] == false ? ' · Hidden' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item['is_cover'] == true)
                            const Icon(Icons.star, color: Color(0xFFF59E0B)),
                          IconButton(
                            tooltip: 'Edit photo',
                            onPressed: () => _edit(context, ref, item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(partnerGalleryProvider(spotId));
    ref.invalidate(publicGalleryProvider(spotId));
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 88, maxWidth: 1920);
    if (file == null || !context.mounted) return;
    final offerings = await ref.read(partnerOfferingsProvider(spotId).future);
    if (!context.mounted) return;
    final caption = TextEditingController();
    var category = 'general';
    String? offeringId;
    var cover = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Photo details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caption,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Caption'),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _mediaCategories
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text(_label(value))))
                    .toList(),
                onChanged: (value) => setDialogState(() => category = value!),
              ),
              if (offerings.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: offeringId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Linked booking offering (optional)'),
                  items: offerings
                      .where((item) => item['is_active'] == true)
                      .map((item) => DropdownMenuItem(
                            value: item['id'].toString(),
                            child: Text(item['display_name']?.toString() ??
                                'Booking offering'),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => offeringId = value),
                ),
              SwitchListTile(
                value: cover,
                onChanged: (value) => setDialogState(() => cover = value),
                title: const Text('Use as destination cover'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Upload')),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await ref.read(connectedOperationsRepositoryProvider).uploadGalleryImage(
          spotId,
          await file.readAsBytes(),
          file.name,
          caption: caption.text,
          category: category,
          offeringId: offeringId,
          cover: cover,
        );
    _refresh(ref);
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final caption =
        TextEditingController(text: item['caption']?.toString() ?? '');
    var category = item['media_category']?.toString() ?? 'general';
    var active = item['is_active'] != false;
    var cover = item['is_cover'] == true;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caption,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Caption'),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _mediaCategories
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text(_label(value))))
                    .toList(),
                onChanged: (value) => setDialogState(() => category = value!),
              ),
              SwitchListTile(
                value: cover,
                onChanged: (value) => setDialogState(() => cover = value),
                title: const Text('Destination cover'),
              ),
              SwitchListTile(
                value: active,
                onChanged: (value) => setDialogState(() => active = value),
                title: const Text('Visible in public gallery'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'remove'),
                child: const Text('Remove')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, 'save'),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (action == null) return;
    final repository = ref.read(connectedOperationsRepositoryProvider);
    if (action == 'remove') {
      await repository.removeGalleryMedia(spotId, item['id'].toString());
    } else {
      await repository.updateGalleryMedia(spotId, item['id'].toString(), {
        'caption': caption.text.trim(),
        'media_category': category,
        'is_cover': cover,
        'is_active': active,
      });
    }
    _refresh(ref);
  }
}

const _offeringTypes = [
  'entrance',
  'cottage',
  'room',
  'tour_package',
  'boat_tour',
  'food_package',
  'meal',
  'equipment_rental',
  'venue',
  'activity',
  'parking',
  'other_approved_service',
];
const _pricingModes = [
  'per_person',
  'per_adult',
  'per_child',
  'per_room_per_night',
  'per_cottage',
  'per_hour',
  'per_day',
  'per_reservation',
  'fixed_package',
];
const _weekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];
const _configurableFields = [
  ('date', 'Visit date', 'date', null),
  ('time', 'Arrival time', 'time', null),
  ('date_range', 'Stay dates', 'date_range', null),
  ('guest_count', 'Number of guests', 'guest_count', null),
  ('adult_count', 'Number of adults', 'adult_count', null),
  ('child_count', 'Number of children', 'child_count', null),
  ('quantity', 'Quantity', 'quantity', null),
  ('nights', 'Number of nights', 'quantity', null),
  ('hours', 'Number of hours', 'quantity', null),
  ('days', 'Number of days', 'quantity', null),
  ('visit_type', 'Visit type', 'select', ['Day use', 'Overnight']),
  (
    'activities',
    'Selected activities',
    'multi_select',
    ['Swimming', 'Snorkeling', 'Sightseeing']
  ),
  ('accessibility', 'Accessibility assistance', 'boolean', null),
  ('special_request', 'Special request', 'short_text', null),
  ('notes', 'Guest notes', 'notes', null),
];
const _mediaCategories = [
  'general',
  'scenery',
  'facilities',
  'activities',
  'accommodation',
  'food',
  'entrance_access',
  'other',
];

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
int? _integer(String value) => int.tryParse(value.trim());
String _label(dynamic value) => value
    .toString()
    .split('_')
    .map((part) =>
        part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
