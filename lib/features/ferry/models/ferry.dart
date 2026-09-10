class Ferry {
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
    this.origin,
    this.destination,
    this.vessel,
    this.departureDate,
    this.advisory,
    this.contactInformation,
    this.referenceUrl,
    this.updatedAt,
  });

  final int id;
  final String uuid;
  final String operator;
  final String route;
  final String departure;
  final String arrival;
  final String duration;
  final double? fare;
  final String status;
  final List<String> days;
  final String? origin;
  final String? destination;
  final String? vessel;
  final DateTime? departureDate;
  final String? advisory;
  final String? contactInformation;
  final String? referenceUrl;
  final DateTime? updatedAt;

  String get vesselName => vessel ?? operator;
  String get shippingLine => operator;
  String get departurePort => origin ?? _routePart(0) ?? route;
  String get arrivalPort =>
      destination ?? _routePart(1) ?? 'Destination unavailable';
  String get departureTime => departure;
  double? get farePrice => fare;

  String? _routePart(int index) {
    final normalized = route.replaceAll('â†’', '→');
    if (!normalized.contains('→')) return null;
    final parts = normalized.split('→');
    return parts.length > index ? parts[index].trim() : null;
  }

  factory Ferry.fromJson(Map<String, dynamic> json) {
    final dep = json['departure_time']?.toString() ??
        json['departure']?.toString() ??
        'Time unavailable';
    final arr = json['arrival_time']?.toString() ??
        json['arrival']?.toString() ??
        'Time unavailable';
    var parsedDays = <String>[];
    final rawDays = json['days_of_week'] ?? json['days'];
    if (rawDays is String && rawDays.isNotEmpty) {
      parsedDays = rawDays.split(',').map((value) => value.trim()).toList();
    } else if (rawDays is List) {
      parsedDays = rawDays.map((value) => value.toString()).toList();
    }

    return Ferry(
      id: _asInt(json['integer_id']) ?? _asInt(json['id']) ?? 0,
      uuid: json['uuid']?.toString() ??
          (json['id'] is String ? json['id'].toString() : ''),
      operator: json['operator']?.toString() ?? 'Operator unavailable',
      route: json['route']?.toString() ?? 'Route unavailable',
      origin: json['origin']?.toString(),
      destination: json['destination']?.toString(),
      vessel: json['vessel_name']?.toString(),
      departureDate:
          DateTime.tryParse(json['departure_date']?.toString() ?? ''),
      departure: dep,
      arrival: arr,
      duration: json['duration']?.toString() ?? _durationBetween(dep, arr),
      fare: (json['fare'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'scheduled',
      days: parsedDays,
      advisory: json['advisory']?.toString(),
      contactInformation: json['contact_information']?.toString(),
      referenceUrl: json['reference_url']?.toString(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static String _durationBetween(String departure, String arrival) {
    int? minutes(String value) {
      final match =
          RegExp(r'^(\d{1,2}):(\d{2})(?:\s*([AP]M))?$', caseSensitive: false)
              .firstMatch(value.trim());
      if (match == null) return null;
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)?.toUpperCase();
      if (period != null) {
        if (hour == 12) hour = 0;
        if (period == 'PM') hour += 12;
      }
      return hour * 60 + minute;
    }

    final start = minutes(departure);
    var end = minutes(arrival);
    if (start == null || end == null) return 'Duration unavailable';
    if (end < start) end += 24 * 60;
    final total = end - start;
    return '${total ~/ 60}h ${(total % 60).toString().padLeft(2, '0')}m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'operator': operator,
        'route': route,
        'origin': origin,
        'destination': destination,
        'vessel_name': vessel,
        'departure_date': departureDate?.toIso8601String().split('T').first,
        'departure_time': departure,
        'arrival_time': arrival,
        'fare': fare,
        'status': status,
        'days_of_week': days.join(','),
        'advisory': advisory,
        'contact_information': contactInformation,
        'reference_url': referenceUrl,
        'is_active': 1,
        'updated_at': updatedAt?.toIso8601String(),
      };
}
