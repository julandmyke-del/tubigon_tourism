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
  final search = TextEditingController();
  String status = 'all';
  DateTime? serviceDate;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ferryAsync = ref.watch(ferrySchedulesListProvider);
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
            child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
        error: (_, __) => _FerryState(
          icon: Icons.cloud_off_rounded,
          title: 'Ferry schedules unavailable',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(ferrySchedulesListProvider),
        ),
        data: (schedules) {
          final statuses = {'all', ...schedules.map((item) => item.status)};
          final query = search.text.trim().toLowerCase();
          final filtered = schedules.where((item) {
            final matchesText = query.isEmpty ||
                item.route.toLowerCase().contains(query) ||
                item.operator.toLowerCase().contains(query) ||
                item.vesselName.toLowerCase().contains(query);
            final matchesStatus = status == 'all' || item.status == status;
            final selectedDay = serviceDate == null
                ? null
                : DateFormat('EEEE').format(serviceDate!).toLowerCase();
            final matchesDate = serviceDate == null ||
                (item.departureDate != null &&
                    DateUtils.isSameDay(item.departureDate, serviceDate)) ||
                (item.departureDate == null &&
                    (item.days.isEmpty ||
                        item.days.any((day) {
                          final normalized = day.toLowerCase();
                          return selectedDay!.startsWith(normalized.length > 3
                              ? normalized.substring(0, 3)
                              : normalized);
                        })));
            return matchesText && matchesStatus && matchesDate;
          }).toList();
          return schedules.isEmpty
              ? _FerryState(
                  icon: Icons.directions_boat_outlined,
                  title: 'No schedules published yet',
                  message: 'Please check again for the latest ferry schedules.',
                  onRetry: () => ref.invalidate(ferrySchedulesListProvider),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 300,
                            child: TextField(
                              controller: search,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                labelText: 'Search route, vessel, or operator',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  statuses.contains(status) ? status : 'all',
                              decoration:
                                  const InputDecoration(labelText: 'Status'),
                              items: statuses
                                  .map((value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value
                                            .replaceAll('_', ' ')
                                            .toUpperCase()),
                                      ))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => status = value ?? 'all'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: serviceDate ?? DateTime.now(),
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 1)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => serviceDate = picked);
                              }
                            },
                            icon: const Icon(Icons.event),
                            label: Text(serviceDate == null
                                ? 'Service date'
                                : DateFormat.yMMMd().format(serviceDate!)),
                          ),
                          if (serviceDate != null)
                            IconButton.outlined(
                              tooltip: 'Clear service date',
                              onPressed: () =>
                                  setState(() => serviceDate = null),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No schedules match these filters.'))
                          : RefreshIndicator(
                              color: const Color(0xFF38BDF8),
                              backgroundColor: const Color(0xFF0F172A),
                              onRefresh: () => ref
                                  .refresh(ferrySchedulesListProvider.future),
                              child: ListView.separated(
                                padding: const EdgeInsets.all(20),
                                itemCount: filtered.length + (offline ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, i) {
                                  if (offline && i == 0) {
                                    return const _OfflineNotice();
                                  }
                                  final scheduleIndex = i - (offline ? 1 : 0);
                                  return _FerryCard(
                                      ferry: filtered[scheduleIndex],
                                      index: scheduleIndex);
                                },
                              ),
                            ),
                    ),
                  ],
                );
        },
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Row(children: [
          Icon(Icons.offline_bolt_rounded, color: Color(0xFFF59E0B)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing saved information. Schedules and advisories may be outdated.',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
          ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: const Color(0xFF38BDF8)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

class _FerryCard extends StatelessWidget {
  const _FerryCard({required this.ferry, required this.index});

  final Ferry ferry;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ferry.vesselName,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(ferry.status).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ferry.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(ferry.status),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                ferry.farePrice == null
                    ? 'Confirm fare'
                    : '₱${ferry.farePrice!.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ferry.departureDate != null) ...[
            Text(
              DateFormat.yMMMMd().format(ferry.departureDate!),
              style: const TextStyle(
                  color: Color(0xFFF59E0B), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ferry.departureTime,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(ferry.departurePort,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12)),
                  ],
                ),
              ),
              const Column(
                children: [
                  Icon(Icons.directions_boat_rounded,
                      color: Color(0xFF38BDF8), size: 22),
                  Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF64748B), size: 16),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(ferry.arrival,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(ferry.arrivalPort,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Operator: ${ferry.shippingLine}',
                  style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text(
                  ferry.days.isEmpty
                      ? 'Date-specific service'
                      : ferry.days.join(', '),
                  style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (ferry.advisory?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Advisory: ${ferry.advisory}',
                  style:
                      const TextStyle(color: Color(0xFFFDE68A), fontSize: 12)),
            ),
          ],
          if (ferry.contactInformation?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Contact: ${ferry.contactInformation}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
          if (ferry.updatedAt != null) ...[
            const SizedBox(height: 6),
            Text(
                'Last updated ${DateFormat.yMMMd().add_jm().format(ferry.updatedAt!.toLocal())}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push(
                  '/map?marker=${Uri.encodeComponent('Tubigon Port')}',
                ),
                icon: const Icon(Icons.map_rounded),
                label: const Text('View Tubigon Port'),
              ),
              FilledButton.icon(
                onPressed: () => context.push(
                  '/map?marker=${Uri.encodeComponent('Tubigon Port')}'
                  '&navigate=true',
                ),
                icon: const Icon(Icons.directions_rounded),
                label: const Text('Directions to Port'),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: (60 * index).ms).fadeIn(duration: 350.ms);
  }

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'scheduled' || 'on_time' => const Color(0xFF34D399),
      'delayed' => const Color(0xFFF59E0B),
      'boarding' => const Color(0xFF38BDF8),
      'departed' || 'completed' => const Color(0xFF818CF8),
      'cancelled' || 'suspended' => const Color(0xFFF87171),
      _ => const Color(0xFF94A3B8),
    };
  }
}
