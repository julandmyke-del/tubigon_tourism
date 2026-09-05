import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'map_provider.dart';

final placeDetailProvider =
    FutureProvider.autoDispose.family<MapMarker, String>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  final cachedMarkers = ref.watch(mapMarkersProvider.future);
  try {
    final response = await client.get(ApiEndpoints.placeById(id));
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid place response.');
    }
    final data = response.data['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid place data.');
    }
    return MapMarker.fromJson(data);
  } catch (_) {
    final cached = await cachedMarkers;
    return cached.firstWhere(
      (marker) =>
          marker.mapLocationId == id ||
          marker.id == id ||
          marker.sourceId == id,
      orElse: () => throw const FormatException(
        'This place is not available in the downloaded data.',
      ),
    );
  }
});
