import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../ferry/models/ferry.dart';
import '../../../ferry/repositories/ferry_repository.dart';

class FerrySchedulePage extends ConsumerStatefulWidget {
  const FerrySchedulePage({super.key});

  @override
  ConsumerState<FerrySchedulePage> createState() => _FerrySchedulePageState();
}

class _FerrySchedulePageState extends ConsumerState<FerrySchedulePage> {
  String? selectedOperator;

  @override
  Widget build(BuildContext context) {
    final ferryAsync = ref.watch(ferrySchedulesListProvider);
    final operatorAsync = ref.watch(ferryOperatorsProvider);
    final offline = !ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.home),
        ),
        title: Text(
          context.tr('ferry_schedules'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: ferryAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (_, __) => _FerryState(
          icon: Icons.cloud_off_rounded,
          title: 'Ferry schedules could not be loaded',
          message: 'Please try again.',
          onRetry: () {
            ref.invalidate(ferrySchedulesListProvider);
            ref.invalidate(ferryOperatorsProvider);
          },
        ),
        data: (schedules) {
          final catalog = operatorAsync.valueOrNull ?? const <FerryOperator>[];
          final operators = _mergeOperators(catalog, schedules);
          final selectedStillExists = selectedOperator == null ||
              operators.any((operator) => operator.key == selectedOperator);
          if (!selectedStillExists) selectedOperator = null;
          final visible = selectedOperator == null
              ? schedules
              : schedules
                  .where((item) => _operatorKey(item) == selectedOperator)
                  .toList(growable: false);

          return RefreshIndicator(
            color: const Color(0xFFF59E0B),
            backgroundColor: const Color(0xFF0F172A),
            onRefresh: () async {
              ref.invalidate(ferryOperatorsProvider);
              final _ = await ref.refresh(ferrySchedulesListProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OperatorFilters(
                          operators: operators,
                          selected: selectedOperator,
                          onSelected: (value) =>
                              setState(() => selectedOperator = value),
                        ),
                        const SizedBox(height: 14),
                        const _TravelNotice(),
                        if (offline) ...[
                          const SizedBox(height: 10),
                          const _OfflineNotice(),
                        ],
                      ],
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          selectedOperator == null
                              ? 'Schedule information is being updated.'
                              : 'No active ${_selectedName(operators)} schedules are currently available.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverList.list(
                      children: _operatorSections(visible),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_OperatorChoice> _mergeOperators(
      List<FerryOperator> catalog, List<Ferry> schedules) {
    final choices = <String, _OperatorChoice>{};
    for (final operator in catalog) {
      final key =
          operator.id.isEmpty ? operator.name.toLowerCase() : operator.id;
      choices[key] = _OperatorChoice(key, operator.name);
    }
    for (final schedule in schedules) {
      choices.putIfAbsent(
        _operatorKey(schedule),
        () => _OperatorChoice(_operatorKey(schedule), schedule.operator),
      );
    }
    final result = choices.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  String _operatorKey(Ferry ferry) => ferry.operatorId?.isNotEmpty == true
      ? ferry.operatorId!
      : ferry.operator.toLowerCase();

  String _selectedName(List<_OperatorChoice> operators) {
    for (final operator in operators) {
      if (operator.key == selectedOperator) return operator.name;
    }
    return 'operator';
  }

  List<Widget> _operatorSections(List<Ferry> schedules) {
    final groups = <String, List<Ferry>>{};
    for (final schedule in schedules) {
      groups.putIfAbsent(_operatorKey(schedule), () => []).add(schedule);
    }
    final ordered = groups.values.toList()
      ..sort((a, b) => a.first.operator
          .toLowerCase()
          .compareTo(b.first.operator.toLowerCase()));
    var cardIndex = 0;
    return ordered.map((operatorSchedules) {
      final routeGroups = <String, List<Ferry>>{};
      for (final schedule in operatorSchedules) {
        final key = '${schedule.departurePort}|${schedule.arrivalPort}';
        routeGroups.putIfAbsent(key, () => []).add(schedule);
      }
      for (final group in routeGroups.values) {
        group.sort((a, b) => a.departure.compareTo(b.departure));
      }
      final first = operatorSchedules.first;
      final vessels = operatorSchedules
          .map((item) => item.vessel)
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return _OperatorSection(
        operator: first.operator,
        vessels: vessels,
        schedules: routeGroups,
        startIndex: cardIndex,
      ).also(() => cardIndex += operatorSchedules.length);
    }).toList(growable: false);
  }
}

extension _Also<T> on T {
  T also(void Function() callback) {
    callback();
    return this;
  }
}

class _OperatorChoice {
  const _OperatorChoice(this.key, this.name);
  final String key;
  final String name;
}

class _OperatorFilters extends StatelessWidget {
  const _OperatorFilters({
    required this.operators,
    required this.selected,
    required this.onSelected,
  });

  final List<_OperatorChoice> operators;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('All'),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
            ),
            ...operators.map((operator) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(operator.name),
                    selected: selected == operator.key,
                    onSelected: (_) => onSelected(operator.key),
                  ),
                )),
          ],
        ),
      );
}

class _TravelNotice extends StatelessWidget {
  const _TravelNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .35)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ferry schedules may change due to weather, operational conditions, or operator advisories. Please confirm the latest schedule before travel.',
              style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12),
            ),
          ),
        ]),
      );
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.offline_bolt_rounded, color: Color(0xFFF59E0B)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing saved information. Schedules and advisories may be outdated.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            ),
          ),
        ]),
      );
}

class _OperatorSection extends StatelessWidget {
  const _OperatorSection({
    required this.operator,
    required this.vessels,
    required this.schedules,
    required this.startIndex,
  });

  final String operator;
  final List<String> vessels;
  final Map<String, List<Ferry>> schedules;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    var index = startIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(operator,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        if (vessels.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(vessels.join(' · '),
              style: const TextStyle(color: Color(0xFF38BDF8))),
        ],
        const SizedBox(height: 14),
        ...schedules.values.map((routeSchedules) {
          final first = routeSchedules.first;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.route_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${first.departurePort} → ${first.arrivalPort}',
                    style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              ...routeSchedules.map((ferry) => _ScheduleRow(
                    ferry: ferry,
                    index: index++,
                  )),
            ]),
          );
        }),
      ]),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.ferry, required this.index});
  final Ferry ferry;
  final int index;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF111C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF243247)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 14, runSpacing: 7, children: [
            _TimeValue(label: 'Departure', value: _time(ferry.departure)),
            _TimeValue(
              label: 'Arrival',
              value: ferry.arrival == null || ferry.arrival!.isEmpty
                  ? 'Not provided'
                  : '${_time(ferry.arrival!)}${ferry.arrivalNextDay ? ' (Next Day)' : ''}',
            ),
            if (ferry.vessel?.isNotEmpty == true)
              _TimeValue(label: 'Vessel', value: ferry.vessel!),
          ]),
          if (_period(ferry) case final period?) ...[
            const SizedBox(height: 7),
            Text(period,
                style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
          if (ferry.status.toLowerCase() == 'cancelled') ...[
            const SizedBox(height: 7),
            const Chip(
              avatar: Icon(Icons.cancel_outlined, size: 17),
              label: Text('Cancelled'),
              side: BorderSide(color: Color(0xFFF87171)),
            ),
          ] else if (ferry.status.toLowerCase() != 'scheduled') ...[
            const SizedBox(height: 7),
            Chip(label: Text(ferry.status.replaceAll('_', ' ').toUpperCase())),
          ],
          if (ferry.advisory?.isNotEmpty == true) ...[
            const SizedBox(height: 7),
            Text(ferry.advisory!,
                style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12)),
          ],
          if (ferry.updatedAt != null) ...[
            const SizedBox(height: 7),
            Text(
              'Last updated ${DateFormat.yMMMd().add_jm().format(ferry.updatedAt!.toLocal())}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ],
        ]),
      ).animate(delay: (40 * index).ms).fadeIn(duration: 250.ms);

  static String _time(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
    if (match == null) return value;
    final date = DateTime(
        2000, 1, 1, int.parse(match.group(1)!), int.parse(match.group(2)!));
    return DateFormat.jm().format(date);
  }

  static String? _period(Ferry ferry) {
    if (ferry.departureDate != null) {
      return 'Schedule date: ${DateFormat.yMMMMd().format(ferry.departureDate!)}';
    }
    if (ferry.effectiveFrom != null && ferry.effectiveUntil != null) {
      return 'Effective ${DateFormat.yMMMMd().format(ferry.effectiveFrom!)} to ${DateFormat.yMMMMd().format(ferry.effectiveUntil!)}';
    }
    if (ferry.effectiveFrom != null) {
      return 'Effective from ${DateFormat.yMMMMd().format(ferry.effectiveFrom!)}';
    }
    return ferry.days.isEmpty ? null : ferry.days.join(', ');
  }
}

class _TimeValue extends StatelessWidget {
  const _TimeValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _FerryState extends StatelessWidget {
  const _FerryState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 58, color: const Color(0xFFF59E0B)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}
