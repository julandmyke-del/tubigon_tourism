import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../providers/admin_providers.dart';

class AdminReservationDetailPage extends ConsumerWidget {
  const AdminReservationDetailPage({
    super.key,
    required this.reservationId,
  });

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservation = ref.watch(adminReservationProvider(reservationId));
    return Scaffold(
      backgroundColor: AdminColors.navy950,
      appBar: AppBar(
        backgroundColor: AdminColors.navy900,
        foregroundColor: AdminColors.textPrimary,
        title: const Text('Reservation Detail'),
      ),
      body: reservation.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdminColors.orange),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load this reservation.',
                  style: TextStyle(color: AdminColors.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(adminReservationProvider(reservationId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final user = data['user'] is Map
              ? Map<String, dynamic>.from(data['user'])
              : const <String, dynamic>{};
          final status = data['status'] is Map
              ? Map<String, dynamic>.from(data['status'])
              : const <String, dynamic>{};
          final rawDate =
              DateTime.tryParse((data['reservation_date'] ?? '').toString());
          final amount = (data['total_amount'] as num?)?.toDouble() ?? 0;
          final hasDisplayedFee =
              data['reservable_type']?.toString() != 'spot' ||
                  data['fee_configured'] == true;
          final rows = <String, String>{
            'Public reference':
                (data['public_reference'] ?? 'Not recorded').toString(),
            'Reservation ID': (data['id'] ?? reservationId).toString(),
            'User': (user['name'] ?? 'Unavailable').toString(),
            'User email': (user['email'] ?? 'Unavailable').toString(),
            'Reserved entity':
                (data['reservable_name'] ?? 'Unavailable').toString(),
            'Entity type':
                (data['reservable_type'] ?? 'Unavailable').toString(),
            'Entity ID': (data['reservable_id'] ?? 'Unavailable').toString(),
            'Date': rawDate == null
                ? 'Not recorded'
                : DateFormat.yMMMMd().format(rawDate.toLocal()),
            'Start time': (data['start_time'] ?? 'Not recorded').toString(),
            'End time': (data['end_time'] ?? 'Not recorded').toString(),
            'Guests': (data['guests'] ?? 0).toString(),
            'Amount': hasDisplayedFee
                ? '₱${NumberFormat('#,##0.00').format(amount)}'
                : 'Fee information unavailable',
            'Status': _label((status['name'] ?? 'unknown').toString()),
            'Notes': (data['notes'] ?? 'None').toString(),
            'Created': (data['created_at'] ?? 'Not recorded').toString(),
            'Updated': (data['updated_at'] ?? 'Not recorded').toString(),
          };
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                color: AdminColors.navy900,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: rows.entries
                        .map((row) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 130,
                                    child: Text(row.key,
                                        style: const TextStyle(
                                            color: AdminColors.textSecondary)),
                                  ),
                                  Expanded(
                                    child: SelectableText(row.value,
                                        style: const TextStyle(
                                            color: AdminColors.textPrimary)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _label(String value) => value
    .split('_')
    .map((part) => part.isEmpty
        ? part
        : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}')
    .join(' ');
