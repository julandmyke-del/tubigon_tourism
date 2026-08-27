import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../ferry/models/ferry.dart';
import '../../../ferry/repositories/ferry_repository.dart';

class FerrySchedulePage extends ConsumerWidget {
  const FerrySchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ferryAsync = ref.watch(ferrySchedulesListProvider);

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
        title: const Text(
          'Ferry Schedules',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
        data: (schedules) => schedules.isEmpty
            ? _FerryState(
                icon: Icons.directions_boat_outlined,
                title: 'No schedules published yet',
                message: 'Please check again for the latest ferry schedules.',
                onRetry: () => ref.invalidate(ferrySchedulesListProvider),
              )
            : RefreshIndicator(
                color: const Color(0xFF38BDF8),
                backgroundColor: const Color(0xFF0F172A),
                onRefresh: () => ref.refresh(ferrySchedulesListProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    return _FerryCard(ferry: schedules[i], index: i);
                  },
                ),
              ),
      ),
    );
  }
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
    final isFastcraft = ferry.duration.contains('1h') ||
        ferry.operator.toLowerCase().contains('fast');

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
                  color: isFastcraft
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                      : const Color(0xFF38BDF8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFastcraft ? 'FastCraft' : 'RoRo Ferry',
                  style: TextStyle(
                    color: isFastcraft
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
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
              Text(ferry.days.join(', '),
                  style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
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
}
