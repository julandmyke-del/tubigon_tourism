import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routes/route_names.dart';
import '../../../emergency/models/emergency_contact.dart';
import '../../../emergency/repositories/emergency_repository.dart';
import '../../../map/providers/map_provider.dart';

class EmergencyContactsPage extends ConsumerWidget {
  const EmergencyContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsListProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.home),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Emergency Contacts'),
      ),
      body: contacts.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF87171))),
        error: (error, _) => _EmergencyState(
          message:
              'Emergency contacts are unavailable. Check your connection and retry.',
          onRetry: () => ref.invalidate(emergencyContactsListProvider),
        ),
        data: (items) => items.isEmpty
            ? _EmergencyState(
                message: 'No active emergency contacts are configured.',
                onRetry: () => ref.invalidate(emergencyContactsListProvider),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(emergencyContactsListProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _EmergencyCard(contact: items[index]),
                ),
              ),
      ),
    );
  }
}

class _EmergencyCard extends ConsumerWidget {
  const _EmergencyCard({required this.contact});
  final EmergencyContact contact;

  Future<void> _confirmAndCall(BuildContext context, String number) async {
    final valid = RegExp(r'^\+?[0-9()\-\s]{3,20}$').hasMatch(number);
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This contact number is not valid.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Call ${contact.name}?'),
        content: Text(
            '$number\n\nYour phone dialer will open. The call is not placed automatically.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open Dialer')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (!await launchUrl(Uri(scheme: 'tel', path: clean)) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone application is available.')),
      );
    }
  }

  void _openMap(BuildContext context, WidgetRef ref, {bool navigate = false}) {
    if (contact.latitude == null || contact.longitude == null) return;
    ref.invalidate(mapMarkersProvider);
    final uri = Uri(
      path: '/map',
      queryParameters: {
        'marker': 'emergency:${contact.uuid}',
        if (navigate) 'navigate': 'true',
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updated = contact.updatedAt == null
        ? null
        : DateFormat.yMMMd().format(contact.updatedAt!.toLocal());
    final hasLocation = contact.latitude != null && contact.longitude != null;
    return Semantics(
      label: '${contact.category}: ${contact.name}, ${contact.phone}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: contact.color.withValues(alpha: .35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                backgroundColor: contact.color.withValues(alpha: .15),
                child: Icon(contact.icon, color: contact.color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.category,
                        style: TextStyle(
                            color: contact.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Text(contact.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
            ),
            _VerificationBadge(verified: contact.isVerified),
          ]),
          const SizedBox(height: 12),
          Text(contact.phone,
              style: TextStyle(
                  color: contact.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          if (contact.alternativePhone?.isNotEmpty == true)
            Text('Alternative: ${contact.alternativePhone}',
                style: const TextStyle(color: Color(0xFFCBD5E1))),
          if (contact.address?.isNotEmpty == true)
            Text(contact.address!,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          if (contact.description?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(contact.description!,
                style: const TextStyle(color: Color(0xFFCBD5E1))),
          ],
          if (contact.operatingHours?.isNotEmpty == true)
            Text('Hours: ${contact.operatingHours}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          if (updated != null) ...[
            const SizedBox(height: 6),
            Text('Last updated: $updated',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: () => _confirmAndCall(context, contact.phone),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('CALL NOW'),
            ),
            if (contact.alternativePhone?.isNotEmpty == true)
              OutlinedButton.icon(
                onPressed: () =>
                    _confirmAndCall(context, contact.alternativePhone!),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                label: const Text('ALT NUMBER'),
              ),
            OutlinedButton.icon(
              onPressed: hasLocation ? () => _openMap(context, ref) : null,
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('VIEW MAP'),
            ),
            OutlinedButton.icon(
              onPressed: hasLocation
                  ? () => _openMap(context, ref, navigate: true)
                  : null,
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: const Text('NAVIGATE'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              (verified ? Colors.green : Colors.amber).withValues(alpha: .15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          verified ? 'Verified' : 'Needs Verification',
          style: TextStyle(
            color: verified ? Colors.greenAccent : Colors.amberAccent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _EmergencyState extends StatelessWidget {
  const _EmergencyState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emergency_rounded,
                size: 58, color: Color(0xFFF87171)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFCBD5E1))),
            const SizedBox(height: 14),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry')),
          ]),
        ),
      );
}
