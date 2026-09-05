import 'providers/map_provider.dart';

enum MapCameraMove { keep, center, fitBounds }

class MapCameraPlan {
  const MapCameraPlan(this.move, this.markers);

  final MapCameraMove move;
  final List<MapMarker> markers;
}

/// Camera movement is planned only for an explicit user filter/search action.
/// Provider refreshes never call this policy, so cache or network updates do
/// not unexpectedly fight the user's current pan/zoom.
MapCameraPlan planMapCameraForFilterChange(
  List<MapMarker> visibleMarkers, {
  required bool navigationActive,
}) {
  if (navigationActive || visibleMarkers.isEmpty) {
    return const MapCameraPlan(MapCameraMove.keep, []);
  }
  if (visibleMarkers.length == 1) {
    return MapCameraPlan(MapCameraMove.center, visibleMarkers);
  }
  return MapCameraPlan(MapCameraMove.fitBounds, visibleMarkers);
}
