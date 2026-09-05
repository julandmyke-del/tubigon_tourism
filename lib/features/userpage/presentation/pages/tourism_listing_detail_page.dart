import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../widgets/place_reviews_panel.dart';

final publicTourismListingProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, listingId) async {
  final response = await ref
      .watch(apiClientProvider)
      .get(ApiEndpoints.tourismListing(listingId));
  final body = response.data;
  if (response.statusCode != 200 ||
      body is! Map ||
      body['status'] != 'success' ||
      body['data'] is! Map) {
    throw const FormatException('This listing is not publicly available.');
  }
  return Map<String, dynamic>.from(body['data'] as Map);
});

class TourismListingDetailPage extends ConsumerWidget {
  const TourismListingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(publicTourismListingProvider(listingId));
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        title: const Text('Tourism Experience'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: listing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.public_off_rounded,
                    size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                const Text(
                  'This listing is unavailable or is still under review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(publicTourismListingProvider(listingId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _ListingBody(data: data),
      ),
    );
  }
}

class _ListingBody extends ConsumerWidget {
  const _ListingBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = data['listing_name']?.toString() ?? 'Tourism experience';
    final type = data['listing_type']?.toString() ?? 'Tourism service';
    final description = data['description']?.toString() ?? '';
    final address = data['address']?.toString() ?? 'Tubigon, Bohol';
    final price = _number(data['price']);
    final capacity = _integer(data['capacity']);
    final duration = _integer(data['duration_minutes']);
    final images = (data['images'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        if (images.isNotEmpty)
          SizedBox(
            height: 240,
            child: PageView.builder(
              itemCount: images.length,
              itemBuilder: (_, index) => Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _ImageFallback(),
              ),
            ),
          )
        else
          const SizedBox(height: 180, child: _ImageFallback()),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(type,
                  style: const TextStyle(
                      color: Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _Info(icon: Icons.place_rounded, text: address),
              if ((data['operating_hours']?.toString() ?? '').isNotEmpty)
                _Info(
                    icon: Icons.schedule_rounded,
                    text: data['operating_hours'].toString()),
              if (duration != null)
                _Info(
                    icon: Icons.timelapse_rounded,
                    text: '$duration minute duration'),
              if (capacity != null)
                _Info(
                    icon: Icons.groups_rounded,
                    text: 'Up to $capacity guests per booking'),
              const SizedBox(height: 16),
              if (description.isNotEmpty)
                Text(description,
                    style:
                        const TextStyle(color: Color(0xFFCBD5E1), height: 1.5)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Price per guest',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                          Text(
                            price > 0
                                ? '₱${price.toStringAsFixed(2)}'
                                : 'No booking fee',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final target = Uri(
                          path: '/reservations/create',
                          queryParameters: {
                            'type': 'tourism_listing',
                            'id': data['id'].toString(),
                            'name': name,
                            'price': price.toString(),
                          },
                        );
                        context.push(target.toString());
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Reserve'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PlaceReviewsPanel(
                reviewableType: 'tourism_listing',
                reviewableId: data['id'].toString(),
                targetName: name,
                onReviewSaved: () => ref.invalidate(
                    publicTourismListingProvider(data['id'].toString())),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static int? _integer(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 19, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 9),
            Expanded(
                child: Text(text,
                    style: const TextStyle(color: Color(0xFFCBD5E1)))),
          ],
        ),
      );
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF162238),
        child: Center(
          child: Icon(Icons.tour_rounded, size: 64, color: Color(0xFFF59E0B)),
        ),
      );
}
