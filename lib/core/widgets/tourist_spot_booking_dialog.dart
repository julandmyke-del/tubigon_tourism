import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showTouristSpotBookingDialog(
  BuildContext context,
  Map<String, dynamic> spot,
) {
  var enabled = spot['is_bookable'] == true || spot['is_bookable'] == 1;
  var mode = spot['booking_mode']?.toString() ?? 'no_reservation';
  final availableDays = <String>{
    ...(spot['booking_available_days'] as List<dynamic>? ?? const [])
        .map((day) => day.toString().toLowerCase()),
  };
  final rawSlots = (spot['booking_time_slots'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((slot) =>
          '${slot['start'] ?? ''}-${slot['end'] ?? ''}${slot['capacity'] == null ? '' : ':${slot['capacity']}'}')
      .join(', ');
  final slots = TextEditingController(text: rawSlots);
  final maxGuests = TextEditingController(
      text: spot['max_guests_per_reservation']?.toString() ?? '');
  final capacity =
      TextEditingController(text: spot['capacity_per_slot']?.toString() ?? '');
  final advance = TextEditingController(
      text: spot['advance_booking_days']?.toString() ?? '');
  final notice = TextEditingController(
      text: spot['minimum_notice_hours']?.toString() ?? '');
  final fee =
      TextEditingController(text: spot['reservation_fee']?.toString() ?? '');
  final instructions = TextEditingController(
      text: spot['booking_instructions']?.toString() ?? '');
  final cancellation = TextEditingController(
      text: spot['cancellation_policy']?.toString() ?? '');
  final cancellationNotice = TextEditingController(
      text: spot['cancellation_notice_hours']?.toString() ?? '');

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Booking · ${spot['name'] ?? 'Tourist spot'}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: enabled,
                title: const Text('Booking enabled'),
                subtitle: const Text(
                    'The public Book action uses this authoritative switch.'),
                onChanged: (value) => setState(() {
                  enabled = value;
                  if (value && mode == 'no_reservation') mode = 'date_only';
                }),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(mode),
                initialValue: mode,
                decoration:
                    const InputDecoration(labelText: 'Reservation mode'),
                items: const [
                  DropdownMenuItem(
                      value: 'no_reservation', child: Text('No Reservation')),
                  DropdownMenuItem(
                      value: 'date_only', child: Text('Date Only')),
                  DropdownMenuItem(
                      value: 'date_time_slot', child: Text('Date + Time Slot')),
                ],
                onChanged: (value) => setState(() {
                  mode = value ?? 'no_reservation';
                  if (mode == 'no_reservation') enabled = false;
                }),
              ),
              const SizedBox(height: 14),
              const Text('Opening days'),
              Wrap(
                spacing: 6,
                children: const [
                  'monday',
                  'tuesday',
                  'wednesday',
                  'thursday',
                  'friday',
                  'saturday',
                  'sunday'
                ]
                    .map((day) => FilterChip(
                          label: Text(day.substring(0, 3).toUpperCase()),
                          selected: availableDays.contains(day),
                          onSelected: (selected) => setState(() => selected
                              ? availableDays.add(day)
                              : availableDays.remove(day)),
                        ))
                    .toList(),
              ),
              if (mode == 'date_time_slot')
                TextField(
                  controller: slots,
                  decoration: const InputDecoration(
                    labelText: 'Time slots',
                    helperText:
                        'Comma-separated: 09:00-10:00:20, 10:00-11:00:15 (capacity optional)',
                  ),
                ),
              Wrap(spacing: 12, runSpacing: 4, children: [
                _numberField(maxGuests, 'Maximum guests'),
                _numberField(capacity, 'Capacity per date/slot'),
                _numberField(advance, 'Advance booking days'),
                _numberField(notice, 'Minimum notice hours'),
                _numberField(fee, 'Verified fee', decimal: true),
                _numberField(cancellationNotice, 'Cancellation notice hours'),
              ]),
              TextField(
                controller: instructions,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Special instructions'),
              ),
              TextField(
                controller: cancellation,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Cancellation policy'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Leave unknown fee, capacity, schedules, and policies blank. Existing reservations remain accessible when booking is disabled.',
                style: TextStyle(fontSize: 12),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsedSlots = <Map<String, dynamic>>[];
              if (mode == 'date_time_slot') {
                for (final value in slots.text.split(',')) {
                  final match =
                      RegExp(r'^\s*(\d{2}:\d{2})-(\d{2}:\d{2})(?::(\d+))?\s*$')
                          .firstMatch(value);
                  if (match == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Use the required time-slot format.')));
                    return;
                  }
                  parsedSlots.add({
                    'start': match.group(1),
                    'end': match.group(2),
                    if (match.group(3) != null)
                      'capacity': int.parse(match.group(3)!),
                  });
                }
                if (parsedSlots.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Add at least one verified time slot.')));
                  return;
                }
              }
              Navigator.pop(dialogContext, {
                'is_bookable': enabled,
                'booking_mode': mode,
                'booking_available_days': availableDays.toList(),
                'booking_time_slots':
                    mode == 'date_time_slot' ? parsedSlots : null,
                'max_guests_per_reservation': _integer(maxGuests.text),
                'capacity_per_slot': _integer(capacity.text),
                'advance_booking_days': _integer(advance.text),
                'minimum_notice_hours': _integer(notice.text),
                'reservation_fee': _decimal(fee.text),
                'booking_instructions': _text(instructions.text),
                'cancellation_policy': _text(cancellation.text),
                'cancellation_notice_hours': _integer(cancellationNotice.text),
              });
            },
            child: const Text('Save Configuration'),
          ),
        ],
      ),
    ),
  );
}

Widget _numberField(TextEditingController controller, String label,
        {bool decimal = false}) =>
    SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
      ),
    );

int? _integer(String value) =>
    value.trim().isEmpty ? null : int.tryParse(value.trim());
double? _decimal(String value) =>
    value.trim().isEmpty ? null : double.tryParse(value.trim());
String? _text(String value) => value.trim().isEmpty ? null : value.trim();
