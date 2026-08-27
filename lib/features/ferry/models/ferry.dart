class Ferry {
  final int id;
  final String uuid;
  final String operator;
  final String route;
  final String departure;
  final String arrival;
  final String duration;
  final double? fare;
  final String status; // 'on_time', 'delayed', 'cancelled'
  final List<String> days;

  String get vesselName => route;
  String get shippingLine => operator;
  String get departurePort =>
      route.contains('→') ? route.split('→').first.trim() : route;
  String get arrivalPort =>
      route.contains('→') ? route.split('→').last.trim() : arrival;
  String get departureTime => departure;
  double? get farePrice => fare;

  const Ferry({
    required this.id,
    required this.uuid,
    required this.operator,
    required this.route,
    required this.departure,
    required this.arrival,
    required this.duration,
    required this.fare,
    required this.status,
    required this.days,
  });

  factory Ferry.fromJson(Map<String, dynamic> json) {
    final dep = json['departure_time'] as String? ??
        json['departure'] as String? ??
        '12:00 PM';
    final arr = json['arrival_time'] as String? ??
        json['arrival'] as String? ??
        '1:30 PM';

    // Parse days
    List<String> parsedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final rawDays = json['days_of_week'] ?? json['days'];
    if (rawDays != null) {
      if (rawDays is String) {
        parsedDays = rawDays.split(',').map((e) => e.trim()).toList();
      } else if (rawDays is List) {
        parsedDays = rawDays.map((e) => e.toString()).toList();
      }
    }

    return Ferry(
      id: _asInt(json['integer_id']) ?? _asInt(json['id']) ?? 0,
      uuid: json['uuid']?.toString() ??
          (json['id'] is String ? json['id'].toString() : ''),
      operator: json['operator'] as String? ?? 'Unknown',
      route: json['route'] as String? ?? 'Tubigon → Cebu',
      departure: dep,
      arrival: arr,
      duration: json['duration'] as String? ?? _durationBetween(dep, arr),
      fare: (json['fare'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'on_time',
      days: parsedDays,
    );
  }

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static String _durationBetween(String departure, String arrival) {
    int? minutes(String value) {
      final match =
          RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)$', caseSensitive: false)
              .firstMatch(value.trim());
      if (match == null) return null;
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();
      if (hour == 12) hour = 0;
      if (period == 'PM') hour += 12;
      return hour * 60 + minute;
    }

    final start = minutes(departure);
    var end = minutes(arrival);
    if (start == null || end == null) return 'Duration unavailable';
    if (end < start) end += 24 * 60;
    final total = end - start;
    final hours = total ~/ 60;
    final mins = total % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'operator': operator,
      'route': route,
      'departure_time': departure,
      'arrival_time': arrival,
      'fare': fare,
      'status': status,
      'days_of_week': days.join(','),
    };
  }
}
