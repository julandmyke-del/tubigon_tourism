import 'providers/map_provider.dart';

String mapMarkerReference(String entityType, Object entityId) =>
    '${entityType.trim()}:${entityId.toString().trim()}';

String mapFocusPathForReference(
  String markerReference, {
  bool directions = false,
}) =>
    Uri(
      path: '/map',
      queryParameters: {
        'marker': markerReference,
        if (directions) 'navigate': 'true',
      },
    ).toString();

String mapFocusPathForEntity({
  required String entityType,
  required Object entityId,
  bool directions = false,
}) =>
    mapFocusPathForReference(
      mapMarkerReference(entityType, entityId),
      directions: directions,
    );

String mapFocusPathForMarker(
  MapMarker marker, {
  bool directions = false,
}) =>
    mapFocusPathForReference(marker.id, directions: directions);
