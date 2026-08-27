enum ItineraryStatus { draft, upcoming, active, completed, archived }

enum ItineraryVisitStatus { planned, visited, skipped }

class ItineraryPlace {
  const ItineraryPlace({
    required this.entityType,
    required this.entityId,
    required this.markerId,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.description,
    this.address,
    this.operatingHours,
    this.images = const [],
    this.isVerified = false,
  });

  final String entityType;
  final String entityId;
  final String markerId;
  final String name;
  final String category;
  final String? description;
  final String? address;
  final double latitude;
  final double longitude;
  final String? operatingHours;
  final List<String> images;
  final bool isVerified;

  factory ItineraryPlace.fromJson(Map<String, dynamic> json) => ItineraryPlace(
        entityType: json['entity_type']?.toString() ?? '',
        entityId: json['entity_id']?.toString() ?? '',
        markerId: json['marker_id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unavailable place',
        category: json['category']?.toString() ?? 'Place',
        description: json['description']?.toString(),
        address: json['address']?.toString(),
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        operatingHours: json['operating_hours']?.toString(),
        images: (json['images'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      );

  Map<String, dynamic> toJson() => {
        'entity_type': entityType,
        'entity_id': entityId,
        'marker_id': markerId,
        'name': name,
        'category': category,
        'description': description,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'operating_hours': operatingHours,
        'images': images,
        'is_verified': isVerified,
      };
}

class ItineraryReservation {
  const ItineraryReservation({
    required this.id,
    this.date,
    this.startTime,
    this.endTime,
    this.status,
  });

  final String id;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String? status;

  factory ItineraryReservation.fromJson(Map<String, dynamic> json) =>
      ItineraryReservation(
        id: json['id']?.toString() ?? '',
        date: json['date']?.toString(),
        startTime: json['start_time']?.toString(),
        endTime: json['end_time']?.toString(),
        status: json['status']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'status': status,
      };
}

class ItineraryItem {
  const ItineraryItem({
    required this.id,
    required this.itineraryId,
    required this.entityType,
    required this.entityId,
    required this.dayNumber,
    required this.sortOrder,
    required this.visitStatus,
    this.plannedStartTime,
    this.plannedEndTime,
    this.notes,
    this.place,
    this.reservation,
  });

  final String id;
  final String itineraryId;
  final String entityType;
  final String entityId;
  final int dayNumber;
  final int sortOrder;
  final String? plannedStartTime;
  final String? plannedEndTime;
  final String? notes;
  final ItineraryVisitStatus visitStatus;
  final ItineraryPlace? place;
  final ItineraryReservation? reservation;

  factory ItineraryItem.fromJson(Map<String, dynamic> json) => ItineraryItem(
        id: json['id']?.toString() ?? '',
        itineraryId: json['itinerary_id']?.toString() ?? '',
        entityType: json['entity_type']?.toString() ?? '',
        entityId: json['entity_id']?.toString() ?? '',
        dayNumber: _int(json['day_number'], 1),
        sortOrder: _int(json['sort_order'], 0),
        plannedStartTime: _time(json['planned_start_time']),
        plannedEndTime: _time(json['planned_end_time']),
        notes: json['notes']?.toString(),
        visitStatus: ItineraryVisitStatus.values.firstWhere(
          (status) => status.name == json['visit_status']?.toString(),
          orElse: () => ItineraryVisitStatus.planned,
        ),
        place: json['place'] is Map
            ? ItineraryPlace.fromJson(
                Map<String, dynamic>.from(json['place'] as Map))
            : null,
        reservation: json['reservation'] is Map
            ? ItineraryReservation.fromJson(
                Map<String, dynamic>.from(json['reservation'] as Map))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itinerary_id': itineraryId,
        'entity_type': entityType,
        'entity_id': entityId,
        'day_number': dayNumber,
        'sort_order': sortOrder,
        'planned_start_time': plannedStartTime,
        'planned_end_time': plannedEndTime,
        'notes': notes,
        'visit_status': visitStatus.name,
        'place': place?.toJson(),
        'reservation': reservation?.toJson(),
      };
}

class Itinerary {
  const Itinerary({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.dayCount,
    required this.status,
    this.description,
    this.travelers,
    this.storedStatus = 'draft',
    this.startLocationType = 'first_stop',
    this.startLocationName,
    this.startLocationId,
    this.startLatitude,
    this.startLongitude,
    this.placeCount = 0,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final int dayCount;
  final int? travelers;
  final ItineraryStatus status;
  final String storedStatus;
  final String startLocationType;
  final String? startLocationName;
  final String? startLocationId;
  final double? startLatitude;
  final double? startLongitude;
  final int placeCount;
  final List<ItineraryItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Itinerary.fromJson(Map<String, dynamic> json) => Itinerary(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Untitled trip',
        description: json['description']?.toString(),
        startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ??
            DateTime.now(),
        endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ??
            DateTime.now(),
        dayCount: _int(json['day_count'], 1),
        travelers:
            json['travelers'] == null ? null : _int(json['travelers'], 1),
        status: ItineraryStatus.values.firstWhere(
          (status) => status.name == json['status']?.toString(),
          orElse: () => ItineraryStatus.draft,
        ),
        storedStatus: json['stored_status']?.toString() ?? 'draft',
        startLocationType:
            json['start_location_type']?.toString() ?? 'first_stop',
        startLocationName: json['start_location_name']?.toString(),
        startLocationId: json['start_location_id']?.toString(),
        startLatitude: _nullableDouble(json['start_latitude']),
        startLongitude: _nullableDouble(json['start_longitude']),
        placeCount: _int(json['place_count'],
            (json['items'] as List<dynamic>? ?? const []).length),
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) =>
                ItineraryItem.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'start_date': _date(startDate),
        'end_date': _date(endDate),
        'day_count': dayCount,
        'travelers': travelers,
        'status': status.name,
        'stored_status': storedStatus,
        'start_location_type': startLocationType,
        'start_location_name': startLocationName,
        'start_location_id': startLocationId,
        'start_latitude': startLatitude,
        'start_longitude': startLongitude,
        'place_count': placeCount,
        'items': items.map((item) => item.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  List<ItineraryItem> itemsForDay(int day) =>
      items.where((item) => item.dayNumber == day).toList(growable: false)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

double _double(dynamic value) => _nullableDouble(value) ?? 0;
double? _nullableDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
int _int(dynamic value, int fallback) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;
String? _time(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return raw.length >= 5 ? raw.substring(0, 5) : raw;
}

String itineraryDate(DateTime value) => _date(value);
String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
