import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../msmepage/models/msme.dart';
import '../../../msmepage/repositories/msme_repository.dart';
import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../map/providers/map_provider.dart';

class MsmeDetailPage extends ConsumerWidget {
  const MsmeDetailPage({super.key, required this.msmeId});

  final int msmeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msmesAsync = ref.watch(msmeListProvider);

    return msmesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF080F1A),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: const Color(0xFF080F1A),
        body: Center(
            child: Text('Error loading MSME details: $err',
                style: const TextStyle(color: Colors.white))),
      ),
      data: (msmes) {
        final msme = msmes.firstWhere(
          (m) => m.id == msmeId,
          orElse: () => const Msme(
            id: 0,
            uuid: '',
            name: 'Not Found',
            category: 'General',
            description: 'Business details not found.',
            phone: '',
            address: '',
            reviewCount: 0,
            color: Color(0xFFF59E0B),
            icon: Icons.store_rounded,
            tagline: '',
            isVerified: false,
            products: [],
            reviews: [],
          ),
        );

        if (msme.id == 0) {
          return const Scaffold(
            backgroundColor: Color(0xFF080F1A),
            body: Center(
                child: Text('MSME not found.',
                    style: TextStyle(color: Colors.white))),
          );
        }

        Color catColor = const Color(0xFFF59E0B);
        IconData catIcon = Icons.store_rounded;

        if (msme.category == 'Food & Dining') {
          catColor = const Color(0xFFF87171);
          catIcon = Icons.restaurant_rounded;
        } else if (msme.category == 'Tour Services') {
          catColor = const Color(0xFF38BDF8);
          catIcon = Icons.sailing_rounded;
        } else if (msme.category == 'Handicrafts') {
          catColor = const Color(0xFFC084FC);
          catIcon = Icons.local_offer_rounded;
        } else if (msme.category == 'Agriculture') {
          catColor = const Color(0xFF34D399);
          catIcon = Icons.agriculture_rounded;
        } else if (msme.category == 'Accommodation') {
          catColor = const Color(0xFFF59E0B);
          catIcon = Icons.home_rounded;
        }

        return Scaffold(
          backgroundColor: const Color(0xFF080F1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Text(
              msme.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: catColor.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(catIcon, color: catColor, size: 36),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            msme.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          if (msme.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFF38BDF8), size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${msme.category}',
                        style: TextStyle(
                            color: catColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms),

                const SizedBox(height: 24),

                // Details List
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business Information',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                          icon: Icons.person_rounded,
                          label: 'Owner',
                          value: msme.ownerName),
                      const Divider(color: Color(0xFF1E293B), height: 24),
                      _DetailRow(
                          icon: Icons.location_on_rounded,
                          label: 'Address',
                          value:
                              (msme.address != null && msme.address!.isNotEmpty)
                                  ? msme.address!
                                  : 'Tubigon, Bohol'),
                      const Divider(color: Color(0xFF1E293B), height: 24),
                      _DetailRow(
                          icon: Icons.phone_rounded,
                          label: 'Contact',
                          value: msme.contactNumber),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 100.ms),

                const SizedBox(height: 24),

                // Description Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About Business',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        msme.description.isNotEmpty
                            ? msme.description
                            : 'Local MSME registered under the Tubigon Tourism Information and Management System.',
                        style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 14,
                            height: 1.6),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 200.ms),

                const SizedBox(height: 32),

                // Contact Action Button
                if (msme.contactNumber.isNotEmpty &&
                    msme.contactNumber != 'N/A')
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = 'tel:${msme.contactNumber}';
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call Business',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showAddToItinerarySheet(
                    context,
                    ref,
                    MapMarker(
                      id: 'msme:${msme.uuid}',
                      sourceId: msme.uuid,
                      sourceIntegerId: msme.id,
                      name: msme.name,
                      description: msme.description,
                      address: msme.address,
                      latitude: msme.latitude,
                      longitude: msme.longitude,
                      category: MapMarkerCategory.msme,
                      categoryName: msme.category,
                      rating: msme.rating,
                      reviewCount: msme.reviewCount,
                      operatingHours: msme.businessHours,
                      contact: msme.phone,
                      isVerified: msme.isVerified,
                    ),
                  ),
                  icon: const Icon(Icons.luggage_rounded),
                  label: const Text('Add to Itinerary'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF59E0B),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
