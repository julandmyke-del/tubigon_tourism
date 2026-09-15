import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localization.dart';

String greetingKeyForHour(int hour) {
  if (hour >= 5 && hour < 12) return 'good_morning';
  if (hour >= 12 && hour < 18) return 'good_afternoon';
  return 'good_evening';
}

/// A minute-resolution clock kept in its own state boundary so time updates do
/// not rebuild the dashboard, its data providers, or the navigation shell.
class LiveGreeting extends StatefulWidget {
  const LiveGreeting({super.key, required this.name});

  final String name;

  @override
  State<LiveGreeting> createState() => _LiveGreetingState();
}

class _LiveGreetingState extends State<LiveGreeting> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(_now),
      alwaysUse24HourFormat: false,
    );
    final weekday = context.tr('weekday_${_now.weekday}');
    final month = context.tr('month_${_now.month}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.tr(greetingKeyForHour(_now.hour))}, ${widget.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$time • $weekday, $month ${_now.day}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
