import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../emergency/models/emergency_contact.dart';
import '../../../emergency/repositories/emergency_repository.dart';
import '../../../map/providers/map_provider.dart';

class EmergencyContactsPage extends ConsumerStatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  ConsumerState<EmergencyContactsPage> createState() =>
      _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends ConsumerState<EmergencyContactsPage> {
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(emergencyContactsListProvider);
    final offline = !ref.watch(isOnlineProvider);
    final cachedAt = EmergencyRepository.cacheUpdatedAt;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.home),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('emergency_contacts')),
          Text('Municipality of Tubigon',
              style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
      body: contacts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EmergencyState(
          message:
              'Emergency contacts are unavailable. Check your connection and retry.',
          onRetry: () => ref.invalidate(emergencyContactsListProvider),
        ),
        data: (items) {
          final activeItems = items
              .where((contact) => contact.isActive)
              .toList(growable: false);
          if (activeItems.isEmpty) {
            return _EmergencyState(
              message: 'No active emergency contacts are configured.',
              onRetry: () => ref.invalidate(emergencyContactsListProvider),
            );
          }
          return Builder(builder: (context) {
            final categories = activeItems
                .map((item) => item.category)
                .toSet()
                .toList(growable: false)
              ..sort();
            final selected =
                _category == 'All' || categories.contains(_category)
                    ? _category
                    : 'All';
            final visible = selected == 'All'
                ? activeItems
                : activeItems
                    .where((item) => item.category == selected)
                    .toList(growable: false);
            return Column(
              children: [
                if (offline)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF59E0B),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      cachedAt == null
                          ? '${context.tr('showing_saved_information')} — Offline copy'
                          : 'Offline copy — last updated ${DateFormat.yMMMd().add_jm().format(cachedAt.toLocal())}',
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w600),
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: ['All', ...categories]
                        .map((category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: selected == category,
                                onSelected: (_) =>
                                    setState(() => _category = category),
                              ),
                            ))
                        .toList(growable: false),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(emergencyContactsListProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _EmergencyCard(contact: visible[index]),
                    ),
                  ),
                ),
              ],
            );
          });
        },
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
    var launched = false;
    try {
      launched = await launchUrl(Uri(scheme: 'tel', path: clean));
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone application is available.')),
      );
    }
  }

  void _openMap(BuildContext context, WidgetRef ref, MapMarker? facility,
      {bool navigate = false}) {
    if (facility == null &&
        (contact.latitude == null || contact.longitude == null)) {
      return;
    }
    ref.invalidate(mapMarkersProvider);
    final uri = Uri(
      path: '/map',
      queryParameters: {
        'marker': facility?.id ?? 'emergency:${contact.uuid}',
        if (navigate) 'navigate': 'true',
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final updated = contact.updatedAt == null
        ? null
        : DateFormat.yMMMd().format(contact.updatedAt!.toLocal());
    final facility = ref
        .watch(mapMarkersProvider)
        .valueOrNull
        ?.where((marker) => marker.emergencyContactId == contact.uuid)
        .firstOrNull;
    final hasLocation = facility?.hasCoordinates == true ||
        (contact.latitude != null && contact.longitude != null);
    return Semantics(
      label: '${contact.category}: ${contact.name}, ${contact.phone}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
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
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700)),
                    if (contact.contactLabel?.isNotEmpty == true)
                      Text(contact.contactLabel!,
                          style: TextStyle(
                              color: contact.color,
                              fontWeight: FontWeight.w700)),
                  ]),
            ),
            _VerificationBadge(
              verified: contact.isVerified &&
                  contact.verificationStatus == 'verified',
            ),
          ]),
          const SizedBox(height: 12),
          Text(contact.phone,
              style: TextStyle(
                  color: contact.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          if (contact.alternativePhone?.isNotEmpty == true)
            Text('Alternative: ${contact.alternativePhone}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          if (contact.address?.isNotEmpty == true)
            Text(contact.address!,
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          if (contact.barangay?.isNotEmpty == true)
            Text('Barangay ${contact.barangay}',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          if (contact.description?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(contact.description!,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ],
          if (contact.operatingHours?.isNotEmpty == true)
            Text('Hours: ${contact.operatingHours}',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          if (contact.availabilityNotes?.isNotEmpty == true)
            Text('Availability: ${contact.availabilityNotes}',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          if (contact.sourceName?.isNotEmpty == true)
            Text('Verified source: ${contact.sourceName}',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
          if (contact.emergencyInstructions?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(contact.emergencyInstructions!,
                style: TextStyle(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w600)),
          ],
          if (updated != null) ...[
            const SizedBox(height: 6),
            Text('Last updated: $updated',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
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
              onPressed:
                  hasLocation ? () => _openMap(context, ref, facility) : null,
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('VIEW MAP'),
            ),
            OutlinedButton.icon(
              onPressed: hasLocation
                  ? () => _openMap(context, ref, facility, navigate: true)
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
  Widget build(BuildContext context) {
    final base = verified ? Colors.green.shade700 : Colors.amber.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        verified ? 'Verified' : 'Needs Verification',
        style: TextStyle(
          color: base,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
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
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry')),
          ]),
        ),
      );
}
