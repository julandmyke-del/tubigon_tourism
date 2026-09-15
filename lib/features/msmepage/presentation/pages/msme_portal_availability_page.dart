import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../map/providers/map_provider.dart';
import '../../providers/msme_portal_providers.dart';
import '../../repositories/msme_repository.dart';
import '../msme_theme.dart';
import '../widgets/msme_portal_states.dart';

class MsmePortalAvailabilityPage extends ConsumerStatefulWidget {
  const MsmePortalAvailabilityPage({super.key});
  @override
  ConsumerState<MsmePortalAvailabilityPage> createState() => _State();
}

class _State extends ConsumerState<MsmePortalAvailabilityPage> {
  String _status = 'open';
  bool _bookingEnabled = false;
  bool _saving = false;
  bool _initialized = false;
  DateTime _focusedDate = DateTime.now();
  final Set<String> _unavailable = {};

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentMsmeProvider);
    if (current.isLoading) {
      return Scaffold(
          backgroundColor: MsmeTheme.bgDark,
          body: const Center(child: CircularProgressIndicator()));
    }
    if (current.hasError) {
      return Scaffold(
        backgroundColor: MsmeTheme.bgDark,
        body: MsmePortalErrorState(
          message: friendlyMsmeError(
              current.error!, 'We couldn’t load your business account.'),
          onRetry: () => ref.invalidate(currentMsmeProvider),
        ),
      );
    }
    final business = current.valueOrNull?.business;
    if (business == null) {
      return Scaffold(
        backgroundColor: MsmeTheme.bgDark,
        body: const MsmeSetupRequired(
          title: 'Availability setup requires a business',
          message:
              'Create your business profile before managing operating status and unavailable dates.',
        ),
      );
    }
    _initialize(business);
    final openingHours = business['opening_hours'] is Map
        ? Map<String, dynamic>.from(business['opening_hours'] as Map)
        : const <String, dynamic>{};
    final upcoming = _unavailable
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .where((date) => !date.isBefore(DateUtils.dateOnly(DateTime.now())))
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Availability Calendar', style: MsmeTheme.headingLarge()),
                Text(
                    'Operating status and blocked dates are enforced by Laravel before a reservation is saved.',
                    style: TextStyle(color: MsmeTheme.textMuted)),
              ]),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: const Text('Save Availability'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth >= 900
                ? (constraints.maxWidth - 14) / 2
                : constraints.maxWidth;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              SizedBox(width: width, child: _calendarCard()),
              SizedBox(
                width: width,
                child: Column(children: [
                  _statusCard(),
                  const SizedBox(height: 14),
                  _scheduleCard(openingHours),
                ]),
              ),
            ]);
          }),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: MsmeTheme.cardDecoration(),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Upcoming Closures', style: MsmeTheme.headingSmall()),
              const SizedBox(height: 10),
              if (upcoming.isEmpty)
                Text('No blocked dates scheduled.',
                    style: TextStyle(color: MsmeTheme.textMuted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: upcoming
                      .take(30)
                      .map((date) => InputChip(
                            label: Text(DateFormat.yMMMd().format(date)),
                            onDeleted: () => setState(
                                () => _unavailable.remove(_dateValue(date))),
                          ))
                      .toList(),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _calendarCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: MsmeTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child:
                Text('Block Specific Dates', style: MsmeTheme.headingSmall()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('Select a date to toggle its availability.',
                style: TextStyle(color: MsmeTheme.textMuted)),
          ),
          CalendarDatePicker(
            initialDate: _focusedDate,
            firstDate: DateUtils.dateOnly(DateTime.now()),
            lastDate: DateTime.now().add(const Duration(days: 730)),
            onDateChanged: (date) {
              final key = _dateValue(date);
              setState(() {
                _focusedDate = date;
                if (!_unavailable.add(key)) _unavailable.remove(key);
              });
            },
          ),
          Text('${_unavailable.length} blocked date(s)',
              style: const TextStyle(color: MsmeTheme.primaryOrange)),
        ]),
      );

  Widget _statusCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: MsmeTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today’s Business Status', style: MsmeTheme.headingSmall()),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Operational status'),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(
                  value: 'temporarily_closed',
                  child: Text('Temporarily Unavailable')),
              DropdownMenuItem(
                  value: 'fully_booked', child: Text('Fully Booked')),
            ],
            onChanged: (value) => setState(() => _status = value ?? 'open'),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Accept online reservations'),
            subtitle: const Text(
                'Turning this off blocks new requests only. Your listing and existing reservations stay available.'),
            value: _bookingEnabled,
            onChanged: (value) => setState(() => _bookingEnabled = value),
          ),
        ]),
      );

  Widget _scheduleCard(Map<String, dynamic> openingHours) => Container(
        padding: const EdgeInsets.all(18),
        decoration: MsmeTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Weekly Operating Schedule',
                    style: MsmeTheme.headingSmall())),
            TextButton(
                onPressed: () => context.go('/msme-portal/profile'),
                child: const Text('Edit')),
          ]),
          if (openingHours.isEmpty)
            Text('Opening hours have not been configured.',
                style: TextStyle(color: MsmeTheme.textMuted))
          else
            ...openingHours.entries.map((entry) {
              final hours = entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : const <String, dynamic>{};
              final closed = hours['closed'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 105, child: Text(_title(entry.key))),
                  Text(
                      closed
                          ? 'Closed'
                          : '${hours['open'] ?? '—'} – ${hours['close'] ?? '—'}',
                      style: TextStyle(
                          color:
                              closed ? MsmeTheme.textMuted : MsmeTheme.green)),
                ]),
              );
            }),
        ]),
      );

  void _initialize(Map<String, dynamic> business) {
    if (_initialized) return;
    _status = business['operational_status']?.toString() ?? 'open';
    _bookingEnabled =
        business['booking_enabled'] == true || business['booking_enabled'] == 1;
    _unavailable.addAll((business['unavailable_dates'] as List? ?? const [])
        .map((item) => item.toString()));
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(msmePortalRepositoryProvider).updateProfile({
        'operational_status': _status,
        'booking_enabled': _bookingEnabled,
        'unavailable_dates': _unavailable.toList()..sort(),
      });
      if (!mounted) return;
      ref.invalidate(currentMsmeProvider);
      ref.invalidate(msmePortalProfileProvider);
      ref.invalidate(msmePortalDashboardStatsProvider);
      ref.invalidate(msmePortalAnalyticsProvider);
      ref.invalidate(msmeListProvider);
      ref.invalidate(mapMarkersProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: MsmeTheme.green,
          content: Text('Availability saved. Tourist booking rules updated.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: MsmeTheme.red,
            content: Text(friendlyMsmeError(
                error, 'We couldn’t save your availability.'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _dateValue(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String _title(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
